using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Tron.Api.Models;

namespace Tron.Api.Services;

public record StoredMediaResult(string StorageKey, long SizeBytes, string Sha256);

public interface IMediaStorage
{
    Task<StoredMediaResult> SaveAsync(
        Guid userId,
        Guid mediaId,
        string extension,
        Stream content,
        CancellationToken ct = default);

    Task<Stream?> OpenReadAsync(string storageKey, CancellationToken ct = default);

    Task DeleteAsync(string storageKey, CancellationToken ct = default);

    bool IsWritable();
}

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(Guid userId, string email, string role);
    string GenerateRefreshToken();
    string HashToken(string rawToken);
}

public class JwtOptions
{
    public const string SectionName = "Jwt";
    public string Issuer { get; set; } = "Tron.Api";
    public string Audience { get; set; } = "Tron.Client";
    public string SigningKey { get; set; } = "tron-dev-signing-key-must-be-at-least-32-bytes-long!";
    public int AccessTokenMinutes { get; set; } = 60;
    public int RefreshTokenDays { get; set; } = 30;
    public int ClockSkewMinutes { get; set; } = 1;
}

public class JwtTokenService(IOptions<JwtOptions> options) : IJwtTokenService
{
    private readonly JwtOptions _options = options.Value;

    public (string Token, DateTime ExpiresAt) CreateAccessToken(Guid userId, string email, string role)
    {
        var expires = DateTime.UtcNow.AddMinutes(_options.AccessTokenMinutes);
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, email),
            new Claim(ClaimTypes.Role, role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: expires,
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }

    public string GenerateRefreshToken()
    {
        Span<byte> bytes = stackalloc byte[32];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes);
    }

    public string HashToken(string rawToken)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawToken));
        return Convert.ToHexStringLower(bytes);
    }
}

public class StorageOptions
{
    public const string SectionName = "Storage";
    public string MediaRoot { get; set; } = ".data/media";
}

public class DiskMediaStorage : IMediaStorage
{
    private readonly string _rootPath;

    public DiskMediaStorage(IOptions<StorageOptions> options)
    {
        var configured = options.Value.MediaRoot;
        _rootPath = Path.IsPathRooted(configured)
            ? configured
            : Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, configured));
        Directory.CreateDirectory(_rootPath);
    }

    public async Task<StoredMediaResult> SaveAsync(
        Guid userId,
        Guid mediaId,
        string extension,
        Stream content,
        CancellationToken ct = default)
    {
        var cleanExt = extension.TrimStart('.').ToLowerInvariant();
        if (!DomainLimits.AllowedAudioExtensions.Contains(cleanExt))
        {
            throw new ApiDomainException("MEDIA_INVALID_EXTENSION", "Định dạng file không được hỗ trợ.");
        }

        var now = DateTime.UtcNow;
        var relativeDir = Path.Combine(userId.ToString("N"), now.ToString("yyyy"), now.ToString("MM"));
        var targetDir = Path.Combine(_rootPath, relativeDir);
        Directory.CreateDirectory(targetDir);

        var fileName = $"{mediaId:N}.{cleanExt}";
        var storageKey = Path.Combine(relativeDir, fileName).Replace('\\', '/');
        var fullPath = GetSafeFullPath(storageKey);
        var tempPath = $"{fullPath}.tmp.{Guid.NewGuid():N}";

        long totalBytes = 0;
        string sha256Hex;
        try
        {
            using (var sha = SHA256.Create())
            await using (var fs = new FileStream(tempPath, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, useAsync: true))
            {
                var buffer = new byte[81920];
                int read;
                while ((read = await content.ReadAsync(buffer.AsMemory(0, buffer.Length), ct)) > 0)
                {
                    totalBytes += read;
                    if (totalBytes > DomainLimits.MaxMediaFileBytes)
                    {
                        throw new ApiDomainException("MEDIA_TOO_LARGE", "File âm thanh vượt quá giới hạn 10 MB.");
                    }
                    sha.TransformBlock(buffer, 0, read, null, 0);
                    await fs.WriteAsync(buffer.AsMemory(0, read), ct);
                }
                sha.TransformFinalBlock([], 0, 0);
                sha256Hex = Convert.ToHexStringLower(sha.Hash!);
            }

            if (totalBytes == 0)
            {
                throw new ApiDomainException("MEDIA_EMPTY_OR_CORRUPT", "File âm thanh trống.");
            }

            File.Move(tempPath, fullPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(tempPath))
            {
                try { File.Delete(tempPath); } catch { /* ignore */ }
            }
        }

        return new StoredMediaResult(storageKey, totalBytes, sha256Hex);
    }

    public Task<Stream?> OpenReadAsync(string storageKey, CancellationToken ct = default)
    {
        var fullPath = GetSafeFullPath(storageKey);
        if (!File.Exists(fullPath))
        {
            return Task.FromResult<Stream?>(null);
        }
        Stream stream = new FileStream(fullPath, FileMode.Open, FileAccess.Read, FileShare.Read, 65536, useAsync: true);
        return Task.FromResult<Stream?>(stream);
    }

    public Task DeleteAsync(string storageKey, CancellationToken ct = default)
    {
        var fullPath = GetSafeFullPath(storageKey);
        if (File.Exists(fullPath))
        {
            File.Delete(fullPath);
        }
        return Task.CompletedTask;
    }

    public bool IsWritable()
    {
        try
        {
            Directory.CreateDirectory(_rootPath);
            var probe = Path.Combine(_rootPath, $".probe-{Guid.NewGuid():N}");
            File.WriteAllText(probe, "ok");
            File.Delete(probe);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private string GetSafeFullPath(string storageKey)
    {
        var normalized = storageKey.Replace('/', Path.DirectorySeparatorChar);
        var combined = Path.GetFullPath(Path.Combine(_rootPath, normalized));
        var rootWithSep = _rootPath.EndsWith(Path.DirectorySeparatorChar)
            ? _rootPath
            : _rootPath + Path.DirectorySeparatorChar;
        if (!combined.StartsWith(rootWithSep, StringComparison.OrdinalIgnoreCase))
        {
            throw new ApiDomainException("MEDIA_INVALID_PATH", "Đường dẫn lưu trữ không hợp lệ.");
        }
        return combined;
    }
}

public static class AudioValidator
{
    public static (string Extension, string ContentType) ValidateFormat(string fileName, ReadOnlySpan<byte> headerBytes)
    {
        var ext = Path.GetExtension(fileName).TrimStart('.').ToLowerInvariant();
        if (!DomainLimits.AllowedAudioExtensions.Contains(ext))
        {
            throw new ApiDomainException("MEDIA_INVALID_EXTENSION", "Chỉ hỗ trợ định dạng MP3, M4A hoặc WAV.");
        }

        if (headerBytes.Length < 12)
        {
            throw new ApiDomainException("MEDIA_EMPTY_OR_CORRUPT", "File âm thanh trống hoặc bị hỏng.");
        }

        var isWav = headerBytes[0] == (byte)'R' && headerBytes[1] == (byte)'I' &&
                    headerBytes[2] == (byte)'F' && headerBytes[3] == (byte)'F' &&
                    headerBytes[8] == (byte)'W' && headerBytes[9] == (byte)'A' &&
                    headerBytes[10] == (byte)'V' && headerBytes[11] == (byte)'E';

        var isM4a = headerBytes[4] == (byte)'f' && headerBytes[5] == (byte)'t' &&
                    headerBytes[6] == (byte)'y' && headerBytes[7] == (byte)'p';

        var isId3 = headerBytes[0] == (byte)'I' && headerBytes[1] == (byte)'D' && headerBytes[2] == (byte)'3';
        var isMpegFrame = headerBytes[0] == 0xFF && (headerBytes[1] & 0xE0) == 0xE0;
        var isMp3 = isId3 || isMpegFrame;

        return ext switch
        {
            "wav" when isWav => ("wav", "audio/wav"),
            "m4a" when isM4a => ("m4a", "audio/mp4"),
            "mp3" when isMp3 => ("mp3", "audio/mpeg"),
            _ => throw new ApiDomainException(
                "MEDIA_SIGNATURE_MISMATCH",
                $"Nội dung file không khớp với định dạng .{ext}.")
        };
    }
}

public static class ShareCodeGenerator
{
    private const string Alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    public static string GenerateCode()
    {
        Span<byte> randomBytes = stackalloc byte[6];
        RandomNumberGenerator.Fill(randomBytes);
        Span<char> chars = stackalloc char[9];
        chars[0] = 'E';
        chars[1] = 'H';
        chars[2] = '-';
        for (var i = 0; i < 6; i++)
        {
            chars[3 + i] = Alphabet[randomBytes[i] & 31];
        }
        return new string(chars);
    }

    public static string NormalizeCode(string raw)
    {
        var trimmed = raw.Trim().ToUpperInvariant();
        if (!trimmed.StartsWith("EH-") && trimmed.Length == 6)
        {
            return $"EH-{trimmed}";
        }
        return trimmed;
    }
}
