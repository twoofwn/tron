using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;
using Tron.Api.Models;
using Tron.Api.Repositories;

namespace Tron.Api.Services;

public class AuthService(
    UserRepository userRepository,
    IJwtTokenService jwtService,
    IMediaStorage mediaStorage,
    IOptions<JwtOptions> jwtOptions)
{
    private readonly PasswordHasher<User> _passwordHasher = new();
    private readonly JwtOptions _jwtOptions = jwtOptions.Value;

    public async Task<ServiceResult<AuthResponse>> RegisterAsync(RegisterRequest req, CancellationToken ct = default)
    {
        var email = req.Email.Trim();
        if (!IsValidEmail(email))
        {
            return ServiceResult<AuthResponse>.Failed("INVALID_EMAIL", "Địa chỉ email không hợp lệ. Vui lòng nhập lại.", 400);
        }

        if (!TryValidatePassword(req.Password, out var pwError))
        {
            return ServiceResult<AuthResponse>.Failed("PASSWORD_WEAK", pwError!, 400);
        }

        var displayName = string.IsNullOrWhiteSpace(req.DisplayName)
            ? email.Split('@')[0]
            : req.DisplayName.Trim();
        if (displayName.Length > 80)
        {
            return ServiceResult<AuthResponse>.Failed("DISPLAY_NAME_INVALID", "Tên hiển thị tối đa 80 ký tự. Vui lòng nhập lại.", 400);
        }

        var normalizedEmail = email.ToUpperInvariant();
        if (await userRepository.ExistsByNormalizedEmailAsync(normalizedEmail, ct))
        {
            return ServiceResult<AuthResponse>.Failed("EMAIL_TAKEN", "Email này đã được đăng ký. Vui lòng dùng email khác hoặc đăng nhập.", 409);
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            NormalizedEmail = normalizedEmail,
            DisplayName = displayName,
            Role = UserRole.User,
            CreatedAt = DateTime.UtcNow,
            LastLoginAt = DateTime.UtcNow,
            Settings = new UserSettings
            {
                ThemeMode = ThemePreference.Dark,
                DefaultCallDelaySeconds = 30,
                UpdatedAt = DateTime.UtcNow
            }
        };
        user.PasswordHash = _passwordHasher.HashPassword(user, req.Password);

        userRepository.AddUser(user);
        await userRepository.SaveChangesAsync(ct);

        var response = await IssueTokensAsync(user, req.DeviceName, ct);
        return ServiceResult<AuthResponse>.Success(response);
    }

    public async Task<ServiceResult<AuthResponse>> LoginAsync(LoginRequest req, CancellationToken ct = default)
    {
        var normalizedEmail = req.Email.Trim().ToUpperInvariant();
        var user = await userRepository.FindByNormalizedEmailAsync(normalizedEmail, ct);
        if (user is null || !user.IsActive)
        {
            return ServiceResult<AuthResponse>.Failed("INVALID_CREDENTIALS", "Email hoặc mật khẩu không đúng. Vui lòng nhập lại.", 401);
        }

        if (user.LockoutEnd.HasValue && user.LockoutEnd.Value > DateTime.UtcNow)
        {
            var minutesLeft = Math.Max(1, (int)Math.Ceiling((user.LockoutEnd.Value - DateTime.UtcNow).TotalMinutes));
            return ServiceResult<AuthResponse>.Failed(
                "ACCOUNT_LOCKED",
                $"Tài khoản tạm khóa do nhập sai nhiều lần. Vui lòng thử lại sau {minutesLeft} phút.",
                423);
        }

        var verifyResult = _passwordHasher.VerifyHashedPassword(user, user.PasswordHash, req.Password);
        if (verifyResult == PasswordVerificationResult.Failed)
        {
            user.FailedLoginCount++;
            if (user.FailedLoginCount >= 5)
            {
                user.LockoutEnd = DateTime.UtcNow.AddMinutes(15);
                user.FailedLoginCount = 0;
            }
            await userRepository.SaveChangesAsync(ct);
            return ServiceResult<AuthResponse>.Failed("INVALID_CREDENTIALS", "Email hoặc mật khẩu không đúng. Vui lòng nhập lại.", 401);
        }

        user.FailedLoginCount = 0;
        user.LockoutEnd = null;
        user.LastLoginAt = DateTime.UtcNow;
        if (verifyResult == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = _passwordHasher.HashPassword(user, req.Password);
        }

        await userRepository.SaveChangesAsync(ct);
        var response = await IssueTokensAsync(user, req.DeviceName, ct);
        return ServiceResult<AuthResponse>.Success(response);
    }

    public async Task<ServiceResult<AuthResponse>> RefreshAsync(RefreshRequest req, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(req.RefreshToken))
        {
            return ServiceResult<AuthResponse>.Failed("INVALID_REFRESH_TOKEN", "Phiên đăng nhập không hợp lệ.", 401);
        }

        var hash = jwtService.HashToken(req.RefreshToken.Trim());
        var stored = await userRepository.FindRefreshTokenByHashAsync(hash, ct);

        if (stored is null || stored.User is null || !stored.User.IsActive)
        {
            return ServiceResult<AuthResponse>.Failed("INVALID_REFRESH_TOKEN", "Phiên đăng nhập không hợp lệ.", 401);
        }

        if (stored.RevokedAt.HasValue)
        {
            var activeTokens = await userRepository.GetActiveRefreshTokensAsync(stored.UserId, ct);
            foreach (var token in activeTokens)
            {
                token.RevokedAt = DateTime.UtcNow;
            }
            await userRepository.SaveChangesAsync(ct);
            return ServiceResult<AuthResponse>.Failed("REFRESH_TOKEN_REUSED", "Phiên đăng nhập đã hết hiệu lực. Vui lòng đăng nhập lại.", 401);
        }

        if (stored.ExpiresAt <= DateTime.UtcNow)
        {
            stored.RevokedAt = DateTime.UtcNow;
            await userRepository.SaveChangesAsync(ct);
            return ServiceResult<AuthResponse>.Failed("REFRESH_TOKEN_EXPIRED", "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.", 401);
        }

        var rawNewRefresh = jwtService.GenerateRefreshToken();
        var newRefresh = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = stored.UserId,
            TokenHash = jwtService.HashToken(rawNewRefresh),
            DeviceName = string.IsNullOrWhiteSpace(req.DeviceName) ? stored.DeviceName : req.DeviceName.Trim(),
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(_jwtOptions.RefreshTokenDays)
        };

        userRepository.AddRefreshToken(newRefresh);
        stored.RevokedAt = DateTime.UtcNow;
        stored.ReplacedById = newRefresh.Id;

        await userRepository.SaveChangesAsync(ct);

        var (accessToken, expiresAt) = jwtService.CreateAccessToken(stored.User.Id, stored.User.Email, stored.User.Role.ToString());
        var profile = await BuildUserProfileAsync(stored.User, ct);
        return ServiceResult<AuthResponse>.Success(new AuthResponse(accessToken, rawNewRefresh, expiresAt, profile));
    }

    public async Task LogoutAsync(Guid userId, string? refreshToken, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            var activeTokens = await userRepository.GetActiveRefreshTokensAsync(userId, ct);
            foreach (var token in activeTokens)
            {
                token.RevokedAt = DateTime.UtcNow;
            }
            await userRepository.SaveChangesAsync(ct);
            return;
        }

        var hash = jwtService.HashToken(refreshToken.Trim());
        var stored = await userRepository.FindRefreshTokenByHashAsync(hash, ct);
        if (stored is not null && stored.UserId == userId)
        {
            stored.RevokedAt = DateTime.UtcNow;
            await userRepository.SaveChangesAsync(ct);
        }
    }

    public async Task<UserProfileDto> GetProfileAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await userRepository.FindByIdAsync(userId, onlyActive: true, ct)
            ?? throw new ApiDomainException("USER_NOT_FOUND", "Không tìm thấy tài khoản.", 404);
        return await BuildUserProfileAsync(user, ct);
    }

    public async Task<ServiceResult<UserProfileDto>> UpdateProfileAsync(Guid userId, UpdateProfileRequest req, CancellationToken ct = default)
    {
        var name = req.DisplayName.Trim();
        if (string.IsNullOrEmpty(name) || name.Length > 80)
        {
            return ServiceResult<UserProfileDto>.Failed("DISPLAY_NAME_INVALID", "Tên hiển thị phải từ 1 đến 80 ký tự. Vui lòng nhập lại.", 400);
        }

        var user = await userRepository.FindByIdAsync(userId, onlyActive: true, ct);
        if (user is null)
        {
            return ServiceResult<UserProfileDto>.Failed("USER_NOT_FOUND", "Không tìm thấy tài khoản.", 404);
        }
        user.DisplayName = name;
        await userRepository.SaveChangesAsync(ct);
        return ServiceResult<UserProfileDto>.Success(await BuildUserProfileAsync(user, ct));
    }

    public async Task<ServiceResult> ChangePasswordAsync(Guid userId, ChangePasswordRequest req, CancellationToken ct = default)
    {
        if (!TryValidatePassword(req.NewPassword, out var pwError))
        {
            return ServiceResult.Failed("PASSWORD_WEAK", pwError!, 400);
        }
        var user = await userRepository.FindByIdAsync(userId, onlyActive: true, ct);
        if (user is null)
        {
            return ServiceResult.Failed("USER_NOT_FOUND", "Không tìm thấy tài khoản.", 404);
        }

        var verify = _passwordHasher.VerifyHashedPassword(user, user.PasswordHash, req.CurrentPassword);
        if (verify == PasswordVerificationResult.Failed)
        {
            return ServiceResult.Failed("INVALID_CURRENT_PASSWORD", "Mật khẩu hiện tại không đúng. Vui lòng nhập lại.", 400);
        }

        user.PasswordHash = _passwordHasher.HashPassword(user, req.NewPassword);
        var activeTokens = await userRepository.GetActiveRefreshTokensAsync(userId, ct);
        foreach (var token in activeTokens)
        {
            token.RevokedAt = DateTime.UtcNow;
        }
        await userRepository.SaveChangesAsync(ct);
        return ServiceResult.Success();
    }

    public async Task DeleteAccountAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await userRepository.FindByIdAsync(userId, onlyActive: false, ct)
            ?? throw new ApiDomainException("USER_NOT_FOUND", "Không tìm thấy tài khoản.", 404);

        var mediaFiles = await userRepository.DeleteUserAndCascadeDependentsAsync(user, ct);
        foreach (var media in mediaFiles)
        {
            if (!string.IsNullOrWhiteSpace(media.StorageKey))
            {
                try { await mediaStorage.DeleteAsync(media.StorageKey, ct); } catch { /* ignore */ }
            }
        }
    }

    private async Task<AuthResponse> IssueTokensAsync(User user, string? deviceName, CancellationToken ct)
    {
        var (accessToken, expiresAt) = jwtService.CreateAccessToken(user.Id, user.Email, user.Role.ToString());
        var rawRefresh = jwtService.GenerateRefreshToken();
        var refresh = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = jwtService.HashToken(rawRefresh),
            DeviceName = string.IsNullOrWhiteSpace(deviceName) ? "TRỐN Client" : deviceName.Trim(),
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(_jwtOptions.RefreshTokenDays)
        };
        userRepository.AddRefreshToken(refresh);
        await userRepository.SaveChangesAsync(ct);

        var profile = await BuildUserProfileAsync(user, ct);
        return new AuthResponse(accessToken, rawRefresh, expiresAt, profile);
    }

    private async Task<UserProfileDto> BuildUserProfileAsync(User user, CancellationToken ct)
    {
        var lastBackup = await userRepository.GetLatestBackupAsync(user.Id, ct);
        var usedBytes = await userRepository.GetUserActiveMediaBytesAsync(user.Id, ct);
        var comboCount = await userRepository.CountUserCombosAsync(user.Id, ct);
        var scenarioCount = await userRepository.CountUserScenariosAsync(user.Id, ct);

        return new UserProfileDto(
            user.Id,
            user.Email,
            user.DisplayName,
            user.Role.ToString(),
            user.CreatedAt,
            lastBackup?.CreatedAt,
            comboCount,
            scenarioCount,
            usedBytes,
            DomainLimits.MaxUserMediaQuotaBytes);
    }

    private static bool IsValidEmail(string email) =>
        !string.IsNullOrWhiteSpace(email) &&
        email.Length <= 256 &&
        Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");

    private static bool TryValidatePassword(string password, out string? errorMessage)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length < 8 || password.Length > 128)
        {
            errorMessage = "Mật khẩu phải từ 8 đến 128 ký tự, gồm cả chữ và số.";
            return false;
        }
        if (!password.Any(char.IsLetter) || !password.Any(char.IsDigit))
        {
            errorMessage = "Mật khẩu phải chứa ít nhất một chữ cái và một chữ số.";
            return false;
        }
        errorMessage = null;
        return true;
    }
}
