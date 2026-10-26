using System.Security.Cryptography;
using Tron.Api.Models;
using Tron.Api.Repositories;

namespace Tron.Api.Services;

public class CatalogAndMediaService(
    CatalogRepository catalogRepository,
    MediaRepository mediaRepository,
    IMediaStorage mediaStorage)
{
    public async Task<IReadOnlyList<ScenarioDto>> GetCatalogScenariosAsync(CancellationToken ct = default)
    {
        var scenarios = await catalogRepository.GetBuiltInScenariosAsync(ct);
        return scenarios.Select(MapScenarioDto).ToList();
    }

    public async Task<ScenarioDto> GetCatalogScenarioByIdAsync(string id, CancellationToken ct = default)
    {
        var alias = await catalogRepository.FindAliasAsync(id, ct);
        var targetId = alias?.ScenarioId ?? id;

        var scenario = await catalogRepository.FindBuiltInScenarioByIdAsync(targetId, ct);
        if (scenario is not null)
        {
            return MapScenarioDto(scenario);
        }

        if (alias is not null && alias.FallbackTitle is not null)
        {
            return new ScenarioDto(
                alias.LegacyId,
                alias.FallbackTitle,
                "personal",
                "builtIn",
                alias.FallbackCaller ?? "Giao hàng",
                "G",
                18,
                null,
                false,
                [
                    new DialogueStepDto("d1", "speech", alias.FallbackDialogue ?? "", null, null, 18)
                ]);
        }

        throw new ApiDomainException("SCENARIO_NOT_FOUND", "Không tìm thấy kịch bản.", 404);
    }

    public async Task<IReadOnlyList<AmbientSoundDto>> GetCatalogAmbientSoundsAsync(CancellationToken ct = default)
    {
        var sounds = await catalogRepository.GetBuiltInAmbientSoundsAsync(ct);
        return sounds.Select(a => new AmbientSoundDto(
            a.Id,
            a.Title,
            a.IconName,
            a.AssetAudioPath,
            a.MediaFileId,
            a.LegacyKey,
            false)).ToList();
    }

    public async Task<IReadOnlyList<RingtoneDto>> GetCatalogRingtonesAsync(CancellationToken ct = default)
    {
        var ringtones = await catalogRepository.GetRingtonesAsync(ct);
        return ringtones.Select(r => new RingtoneDto(r.Id, r.Title, r.AssetAudioPath)).ToList();
    }

    public async Task<MediaCheckResponse> CheckMediaAsync(Guid userId, MediaCheckRequest req, CancellationToken ct = default)
    {
        var hashes = req.Sha256List
            .Where(h => !string.IsNullOrWhiteSpace(h))
            .Select(h => h.Trim().ToLowerInvariant())
            .Distinct()
            .ToList();

        if (hashes.Count == 0)
        {
            return new MediaCheckResponse([], []);
        }

        var existingRows = await mediaRepository.GetUserMediaByHashesAsync(userId, hashes, ct);
        var existingDtos = existingRows
            .GroupBy(m => m.Sha256)
            .Select(g =>
            {
                var first = g.First();
                return new MediaCheckItemDto(first.Sha256, first.Id, first.Extension, first.SizeBytes);
            })
            .ToList();

        var foundSet = existingDtos.Select(x => x.Sha256).ToHashSet();
        var missing = hashes.Where(h => !foundSet.Contains(h)).ToList();

        return new MediaCheckResponse(existingDtos, missing);
    }

    public async Task<MediaUploadResponse> UploadMediaAsync(
        Guid userId,
        string originalFileName,
        MediaKind kind,
        Stream fileStream,
        long? declaredLength,
        CancellationToken ct = default)
    {
        if (declaredLength.HasValue && declaredLength.Value > DomainLimits.MaxMediaFileBytes)
        {
            throw new ApiDomainException("MEDIA_TOO_LARGE", "File âm thanh vượt quá giới hạn 10 MB.");
        }

        await using var bufferStream = new MemoryStream();
        var header = new byte[16];
        var headerRead = await fileStream.ReadAsync(header.AsMemory(0, header.Length), ct);
        if (headerRead < 12)
        {
            throw new ApiDomainException("MEDIA_EMPTY_OR_CORRUPT", "File âm thanh trống hoặc không hợp lệ.");
        }

        var (ext, contentType) = AudioValidator.ValidateFormat(originalFileName, header.AsSpan(0, headerRead));
        await bufferStream.WriteAsync(header.AsMemory(0, headerRead), ct);

        var copyBuf = new byte[65536];
        int n;
        while ((n = await fileStream.ReadAsync(copyBuf.AsMemory(0, copyBuf.Length), ct)) > 0)
        {
            if (bufferStream.Length + n > DomainLimits.MaxMediaFileBytes)
            {
                throw new ApiDomainException("MEDIA_TOO_LARGE", "File âm thanh vượt quá giới hạn 10 MB.");
            }
            await bufferStream.WriteAsync(copyBuf.AsMemory(0, n), ct);
        }

        bufferStream.Position = 0;
        var sha256Hex = Convert.ToHexStringLower(SHA256.HashData(bufferStream.ToArray()));

        var existing = await mediaRepository.FindUserMediaByHashAsync(userId, sha256Hex, ct);
        if (existing is not null)
        {
            var streamCheck = await mediaStorage.OpenReadAsync(existing.StorageKey, ct);
            if (streamCheck is not null)
            {
                await streamCheck.DisposeAsync();
                existing.OrphanedAt = null;
                await mediaRepository.SaveChangesAsync(ct);
                return new MediaUploadResponse(existing.Id, existing.Sha256, existing.Extension, existing.SizeBytes, existing.ContentType);
            }
        }

        var currentUsage = await mediaRepository.GetUserActiveUsageBytesAsync(userId, ct);
        if (currentUsage + bufferStream.Length > DomainLimits.MaxUserMediaQuotaBytes)
        {
            throw new ApiDomainException("QUOTA_EXCEEDED", "Đã vượt hạn mức lưu trữ âm thanh (200 MB).");
        }

        bufferStream.Position = 0;
        var mediaId = existing?.Id ?? Guid.NewGuid();
        var stored = await mediaStorage.SaveAsync(userId, mediaId, ext, bufferStream, ct);

        if (existing is null)
        {
            var media = new MediaFile
            {
                Id = mediaId,
                OwnerId = userId,
                Kind = kind,
                OriginalName = Path.GetFileName(originalFileName),
                ContentType = contentType,
                Extension = ext,
                SizeBytes = stored.SizeBytes,
                Sha256 = stored.Sha256,
                StorageKey = stored.StorageKey,
                CreatedAt = DateTime.UtcNow,
                OrphanedAt = null
            };
            mediaRepository.Add(media);
        }
        else
        {
            existing.StorageKey = stored.StorageKey;
            existing.SizeBytes = stored.SizeBytes;
            existing.OrphanedAt = null;
        }

        await mediaRepository.SaveChangesAsync(ct);
        return new MediaUploadResponse(mediaId, stored.Sha256, ext, stored.SizeBytes, contentType);
    }

    public async Task<(MediaFile Metadata, Stream Stream)> OpenUserMediaAsync(Guid userId, Guid mediaId, CancellationToken ct = default)
    {
        var media = await mediaRepository.FindAccessibleMediaByIdAsync(userId, mediaId, ct)
            ?? throw new ApiDomainException("MEDIA_NOT_FOUND", "Không tìm thấy file âm thanh.", 404);

        var stream = await mediaStorage.OpenReadAsync(media.StorageKey, ct)
            ?? throw new ApiDomainException("MEDIA_FILE_MISSING", "File âm thanh không còn trên ổ đĩa.", 404);

        return (media, stream);
    }

    public static ScenarioDto MapScenarioDto(Scenario s) =>
        new(
            s.Id,
            s.Title,
            LowerFirst(s.Category.ToString()),
            LowerFirst(s.Source.ToString()),
            s.CallerName,
            s.Initial,
            s.EstimatedSeconds,
            s.DefaultAmbientSoundId,
            s.IsPro,
            s.Steps
                .OrderBy(st => st.Order)
                .Select(st => new DialogueStepDto(
                    st.Id,
                    LowerFirst(st.Type.ToString()),
                    st.Text,
                    st.AssetAudioPath,
                    st.MediaFileId,
                    st.Seconds))
                .ToList());

    private static string LowerFirst(string val) =>
        string.IsNullOrEmpty(val) ? val : char.ToLowerInvariant(val[0]) + val[1..];
}
