using System.Text.Json;
using Tron.Api.Models;
using Tron.Api.Repositories;

namespace Tron.Api.Services;

public class BackupAndShareService(
    BackupRepository backupRepo,
    ShareRepository shareRepo,
    MediaRepository mediaRepo,
    IMediaStorage mediaStorage)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Converters = { new FlexibleGuidJsonConverter() }
    };

    public async Task<BackupStatusDto> GetBackupStatusAsync(Guid userId, CancellationToken ct = default)
    {
        var latestBackup = await backupRepo.GetLatestBackupAsync(userId, ct);
        var comboCount = await backupRepo.CountCombosAsync(userId, ct);
        var scenarioCount = await backupRepo.CountScenariosAsync(userId, ct);
        var ambientCount = await backupRepo.CountAmbientsAsync(userId, ct);
        var (mediaCount, totalMediaBytes) = await backupRepo.GetActiveMediaStatsAsync(userId, ct);

        return new BackupStatusDto(
            latestBackup?.CreatedAt,
            latestBackup?.DeviceName,
            comboCount,
            scenarioCount,
            ambientCount,
            mediaCount,
            totalMediaBytes,
            DomainLimits.MaxUserMediaQuotaBytes);
    }

    public async Task<BackupStatusDto> SaveBackupSnapshotAsync(
        Guid userId,
        BackupSnapshotRequest request,
        CancellationToken ct = default)
    {
        if (request.Combos.Count > DomainLimits.MaxUserCombos)
        {
            throw new ApiDomainException("BACKUP_LIMIT_EXCEEDED", $"Số lượng combo vượt quá giới hạn ({DomainLimits.MaxUserCombos}).");
        }

        if (request.CustomScenarios.Count > DomainLimits.MaxUserScenarios)
        {
            throw new ApiDomainException("BACKUP_LIMIT_EXCEEDED", $"Số lượng kịch bản cá nhân vượt quá giới hạn ({DomainLimits.MaxUserScenarios}).");
        }

        await using var tx = await backupRepo.BeginTransactionAsync(ct);

        // 1. Upsert UserSettings
        var settings = await backupRepo.GetUserSettingsAsync(userId, asNoTracking: false, ct);
        if (settings is null)
        {
            settings = new UserSettings
            {
                UserId = userId,
                ThemeMode = ParseTheme(request.Settings.ThemeMode),
                DefaultCallDelaySeconds = NormalizeCallDelay(request.Settings.DefaultCallDelaySeconds),
                UpdatedAt = DateTime.UtcNow
            };
            backupRepo.AddUserSettings(settings);
        }
        else
        {
            settings.ThemeMode = ParseTheme(request.Settings.ThemeMode);
            settings.DefaultCallDelaySeconds = NormalizeCallDelay(request.Settings.DefaultCallDelaySeconds);
            settings.UpdatedAt = DateTime.UtcNow;
        }

        // Kiểm tra file của combo TRƯỚC khi xoá dữ liệu cũ, để request bị từ chối không làm mất gì.
        var comboMediaIds = request.Combos
            .SelectMany(c => new[] { c.RingtoneMediaId, c.CustomBackgroundMediaId, c.VoiceMediaId, c.VideoMediaId, c.AvatarMediaId })
            .Where(id => id.HasValue && id.Value != Guid.Empty)
            .Select(id => id!.Value)
            .ToHashSet();
        if (comboMediaIds.Count > 0)
        {
            var owned = await mediaRepo.GetOwnedMediaIdsAsync(userId, comboMediaIds, ct);
            if (owned.Count != comboMediaIds.Count)
            {
                throw new ApiDomainException("MEDIA_NOT_FOUND", "File âm thanh không tồn tại hoặc không thuộc tài khoản này.");
            }
        }

        // App bản cũ (hoặc khi tải giọng lên lỗi) không gửi voiceMediaId: giữ giọng đang có trên server.
        var previousVoices = await backupRepo.GetComboVoiceIdsAsync(userId, ct);
        // Tương tự cho loại cuộc gọi và video người gọi.
        var previousVideos = await backupRepo.GetComboVideosAsync(userId, ct);
        // Và ảnh đại diện: app bản cũ không gửi avatarMediaId thì giữ ảnh đang có.
        var previousAvatars = await backupRepo.GetComboAvatarIdsAsync(userId, ct);

        // 2. Replace existing custom Combos, Scenarios, AmbientSounds for this user
        await backupRepo.ClearUserSnapshotEntitiesAsync(userId, ct);

        var referencedMediaIds = new HashSet<Guid>();

        // 3. Insert Custom AmbientSounds
        var ambientOrder = 100;
        foreach (var dto in request.CustomAmbientSounds)
        {
            var id = string.IsNullOrWhiteSpace(dto.Id) ? $"custom_bg_{Guid.NewGuid():N}" : dto.Id.Trim();
            if (!id.StartsWith($"u_{userId:N}_", StringComparison.OrdinalIgnoreCase))
            {
                id = $"u_{userId:N}_{id}";
            }

            if (dto.MediaFileId.HasValue)
            {
                referencedMediaIds.Add(dto.MediaFileId.Value);
            }

            backupRepo.AddAmbientSound(new AmbientSound
            {
                Id = id,
                OwnerId = userId,
                Title = dto.Title.Trim(),
                IconName = string.IsNullOrWhiteSpace(dto.IconName) ? "music" : dto.IconName.Trim(),
                AssetAudioPath = dto.AudioPath,
                MediaFileId = dto.MediaFileId,
                LegacyKey = dto.Id,
                SortOrder = ambientOrder++,
                CreatedAt = DateTime.UtcNow
            });
        }

        // 4. Insert Custom Scenarios + Steps
        foreach (var dto in request.CustomScenarios)
        {
            var rawId = string.IsNullOrWhiteSpace(dto.Id) ? $"custom_sc_{Guid.NewGuid():N}" : dto.Id.Trim();
            var scopedId = rawId.StartsWith($"u_{userId:N}_", StringComparison.OrdinalIgnoreCase)
                ? rawId
                : $"u_{userId:N}_{rawId}";

            var scenario = new Scenario
            {
                Id = scopedId,
                OwnerId = userId,
                Title = dto.Title.Trim(),
                Category = ParseCategory(dto.Category),
                Source = ScenarioSource.User,
                CallerName = string.IsNullOrWhiteSpace(dto.CallerName) ? "Người gọi" : dto.CallerName.Trim(),
                Initial = string.IsNullOrWhiteSpace(dto.Initial) ? "N" : dto.Initial.Trim()[..1].ToUpperInvariant(),
                EstimatedSeconds = dto.EstimatedSeconds,
                DefaultAmbientSoundId = dto.DefaultBackgroundId,
                IsPro = dto.IsPro,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            var stepOrder = 1;
            foreach (var stepDto in dto.Steps)
            {
                if (stepDto.MediaFileId.HasValue)
                {
                    referencedMediaIds.Add(stepDto.MediaFileId.Value);
                }

                var isWait = stepDto.Type.Equals("wait", StringComparison.OrdinalIgnoreCase) ||
                             stepDto.Type.Equals("waitForUser", StringComparison.OrdinalIgnoreCase);

                scenario.Steps.Add(new DialogueStep
                {
                    Id = $"{scopedId}-s{stepOrder}",
                    ScenarioId = scopedId,
                    Order = stepOrder++,
                    Type = isWait ? DialogueStepType.Wait : DialogueStepType.Speech,
                    Text = stepDto.Text ?? string.Empty,
                    AssetAudioPath = stepDto.AudioPath,
                    MediaFileId = stepDto.MediaFileId,
                    Seconds = Math.Max(1, stepDto.Seconds)
                });
            }

            backupRepo.AddScenario(scenario);
        }

        // 5. Insert Combos + Backgrounds
        var comboOrder = 1;
        foreach (var dto in request.Combos)
        {
            if (dto.RingtoneMediaId.HasValue)
            {
                referencedMediaIds.Add(dto.RingtoneMediaId.Value);
            }
            if (dto.CustomBackgroundMediaId.HasValue)
            {
                referencedMediaIds.Add(dto.CustomBackgroundMediaId.Value);
            }
            var comboId = dto.Id == Guid.Empty ? Guid.NewGuid() : dto.Id;
            var voiceMediaId = dto.VoiceMediaId switch
            {
                null => previousVoices.GetValueOrDefault(comboId),
                var id when id == Guid.Empty => null,
                var id => id,
            };
            if (voiceMediaId.HasValue)
            {
                // Kể cả giọng được giữ lại, để bước dưới không đánh dấu nó là mồ côi.
                referencedMediaIds.Add(voiceMediaId.Value);
            }

            var hadCombo = previousVideos.TryGetValue(comboId, out var previousVideo);
            var videoMediaId = dto.VideoMediaId switch
            {
                null => hadCombo ? previousVideo.VideoMediaId : null,
                var id when id == Guid.Empty => null,
                var id => id,
            };
            if (videoMediaId.HasValue)
            {
                referencedMediaIds.Add(videoMediaId.Value);
            }

            var avatarMediaId = dto.AvatarMediaId switch
            {
                null => previousAvatars.GetValueOrDefault(comboId),
                var id when id == Guid.Empty => null,
                var id => id,
            };
            if (avatarMediaId.HasValue)
            {
                referencedMediaIds.Add(avatarMediaId.Value);
            }

            var combo = new Combo
            {
                Id = comboId,
                OwnerId = userId,
                Name = string.IsNullOrWhiteSpace(dto.Name) ? "Combo" : dto.Name.Trim(),
                ScenarioId = dto.ScenarioId,
                CallInterface = ParseCallInterface(dto.CallInterface),
                RingtoneType = ParseRingtone(dto.RingtoneType),
                RingtoneMediaId = dto.RingtoneMediaId,
                CustomBackgroundMediaId = dto.CustomBackgroundMediaId,
                VoiceMediaId = voiceMediaId,
                CallType = UserDataService.ParseCallType(dto.CallType)
                    ?? (hadCombo ? previousVideo.CallType : CallType.Voice),
                VideoMediaId = videoMediaId,
                AvatarMediaId = avatarMediaId,
                // App bản cũ không gửi VideoEndAction: giữ tên người gọi và cách kết thúc đang có.
                CallerName = UserDataService.ParseVideoEndAction(dto.VideoEndAction) is null && hadCombo
                    ? previousVideo.CallerName
                    : UserDataService.CleanCallerName(dto.CallerName),
                VideoEndAction = UserDataService.ParseVideoEndAction(dto.VideoEndAction)
                    ?? (hadCombo ? previousVideo.VideoEndAction : VideoEndAction.HangUp),
                BackgroundVolume = Math.Clamp(dto.BackgroundVolume, 0m, 1m),
                BackgroundOverridden = dto.BackgroundOverridden,
                SortOrder = comboOrder++,
                CreatedAt = dto.CreatedAt == default ? DateTime.UtcNow : dto.CreatedAt,
                UpdatedAt = DateTime.UtcNow
            };

            var bgOrder = 1;
            foreach (var bgId in dto.BackgroundSoundIds.Distinct())
            {
                if (!string.IsNullOrWhiteSpace(bgId) && !bgId.Equals("none", StringComparison.OrdinalIgnoreCase))
                {
                    combo.Backgrounds.Add(new ComboBackground
                    {
                        OwnerId = userId,
                        ComboId = comboId,
                        AmbientSoundId = bgId,
                        Order = bgOrder++
                    });
                }
            }

            backupRepo.AddCombo(combo);
        }

        // 6. Update MediaFile orphan status for this user
        var activeSharedMediaIds = await backupRepo.GetActiveSharedMediaIdsAsync(userId, ct);
        foreach (var id in activeSharedMediaIds)
        {
            referencedMediaIds.Add(id);
        }

        var userMedia = await backupRepo.GetUserMediaFilesAsync(userId, onlyActive: false, ct);
        var activeMediaCount = 0;
        var activeMediaBytes = 0L;

        foreach (var media in userMedia)
        {
            if (referencedMediaIds.Contains(media.Id))
            {
                media.OrphanedAt = null;
                activeMediaCount++;
                activeMediaBytes += media.SizeBytes;
            }
            else if (media.OrphanedAt is null)
            {
                media.OrphanedAt = DateTime.UtcNow;
            }
        }

        // 7. Record Backup entry
        var backup = new Backup
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            DeviceName = string.IsNullOrWhiteSpace(request.DeviceName) ? "TRỐN Client" : request.DeviceName.Trim(),
            AppVersion = string.IsNullOrWhiteSpace(request.AppVersion) ? "1.0.0" : request.AppVersion.Trim(),
            ComboCount = request.Combos.Count,
            ScenarioCount = request.CustomScenarios.Count,
            AmbientCount = request.CustomAmbientSounds.Count,
            MediaCount = activeMediaCount,
            TotalMediaBytes = activeMediaBytes,
            CreatedAt = DateTime.UtcNow
        };
        backupRepo.AddBackup(backup);

        await backupRepo.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return new BackupStatusDto(
            backup.CreatedAt,
            backup.DeviceName,
            backup.ComboCount,
            backup.ScenarioCount,
            backup.AmbientCount,
            backup.MediaCount,
            backup.TotalMediaBytes,
            DomainLimits.MaxUserMediaQuotaBytes);
    }

    public async Task<BackupRestoreResponse> GetBackupRestoreAsync(Guid userId, CancellationToken ct = default)
    {
        var status = await GetBackupStatusAsync(userId, ct);
        var settings = await backupRepo.GetUserSettingsAsync(userId, asNoTracking: true, ct);

        var customAmbients = await backupRepo.GetUserAmbientSoundsAsync(userId, ct);
        var customScenarios = await backupRepo.GetUserScenariosWithStepsAsync(userId, ct);
        var combos = await backupRepo.GetUserCombosWithBackgroundsAsync(userId, ct);
        var mediaFiles = await backupRepo.GetUserMediaFilesAsync(userId, onlyActive: true, ct);

        var prefix = $"u_{userId:N}_";

        return new BackupRestoreResponse(
            status,
            new UserSettingsDto(
                (settings?.ThemeMode ?? ThemePreference.Dark).ToString().ToLowerInvariant(),
                settings?.DefaultCallDelaySeconds ?? 30),
            customAmbients.Select(a => new AmbientSoundDto(
                a.LegacyKey ?? (a.Id.StartsWith(prefix) ? a.Id[prefix.Length..] : a.Id),
                a.Title,
                a.IconName,
                a.AssetAudioPath,
                a.MediaFileId,
                a.LegacyKey,
                true)).ToList(),
            customScenarios.Select(s => new ScenarioDto(
                s.Id.StartsWith(prefix) ? s.Id[prefix.Length..] : s.Id,
                s.Title,
                MapCategoryString(s.Category),
                "user",
                s.CallerName,
                s.Initial,
                s.EstimatedSeconds,
                s.DefaultAmbientSoundId,
                s.IsPro,
                s.Steps.Select(st => new DialogueStepDto(
                    st.Id,
                    st.Type == DialogueStepType.Wait ? "wait" : "speech",
                    st.Text,
                    st.AssetAudioPath,
                    st.MediaFileId,
                    st.Seconds)).ToList())).ToList(),
            combos.Select(c => new BackupComboDto(
                c.Id,
                c.Name,
                c.ScenarioId.StartsWith(prefix) ? c.ScenarioId[prefix.Length..] : c.ScenarioId,
                MapCallInterfaceString(c.CallInterface),
                MapRingtoneString(c.RingtoneType),
                c.RingtoneMediaId,
                c.Backgrounds.Select(b => b.AmbientSoundId).ToList(),
                c.CustomBackgroundMediaId,
                c.BackgroundVolume,
                c.BackgroundOverridden,
                c.CreatedAt,
                c.VoiceMediaId,
                UserDataService.MapCallTypeString(c.CallType),
                c.VideoMediaId,
                c.CallerName,
                UserDataService.MapVideoEndActionString(c.VideoEndAction),
                c.AvatarMediaId)).ToList(),
            mediaFiles.Select(m => new MediaCheckItemDto(m.Sha256, m.Id, m.Extension, m.SizeBytes)).ToList());
    }

    public async Task<ServiceResult<ShareSummaryDto>> CreateShareAsync(
        Guid userId,
        CreateShareRequest request,
        CancellationToken ct = default)
    {
        if (request.Combos.Count == 0 && request.CustomScenarios.Count == 0)
        {
            return ServiceResult<ShareSummaryDto>.Failed("SHARE_EMPTY", "Vui lòng chọn ít nhất 1 combo để chia sẻ.", 400);
        }

        if (request.Combos.Count > DomainLimits.MaxSharePackageCombos)
        {
            return ServiceResult<ShareSummaryDto>.Failed("SHARE_LIMIT_EXCEEDED", $"Gói chia sẻ tối đa {DomainLimits.MaxSharePackageCombos} combo.", 400);
        }

        var mediaIds = new HashSet<Guid>();
        // Ảnh đại diện luôn đi theo combo (nhẹ), kể cả khi không kèm âm thanh và video.
        foreach (var c in request.Combos)
        {
            if (c.AvatarMediaId is { } avatarId && avatarId != Guid.Empty) mediaIds.Add(avatarId);
        }
        if (request.IncludeAudio)
        {
            foreach (var c in request.Combos)
            {
                if (c.RingtoneMediaId.HasValue) mediaIds.Add(c.RingtoneMediaId.Value);
                if (c.CustomBackgroundMediaId.HasValue) mediaIds.Add(c.CustomBackgroundMediaId.Value);
                if (c.VoiceMediaId.HasValue) mediaIds.Add(c.VoiceMediaId.Value);
                if (c.VideoMediaId.HasValue) mediaIds.Add(c.VideoMediaId.Value);
            }
            foreach (var s in request.CustomScenarios)
            {
                foreach (var st in s.Steps)
                {
                    if (st.MediaFileId.HasValue) mediaIds.Add(st.MediaFileId.Value);
                }
            }
            foreach (var a in request.CustomAmbientSounds)
            {
                if (a.MediaFileId.HasValue) mediaIds.Add(a.MediaFileId.Value);
            }
        }

        var userMedia = mediaIds.Count > 0
            ? await mediaRepo.GetOwnedMediasByIdsAsync(userId, mediaIds, ct)
            : [];

        var totalBytes = userMedia.Sum(m => m.SizeBytes);
        if (totalBytes > DomainLimits.MaxSharePackageBytes)
        {
            return ServiceResult<ShareSummaryDto>.Failed("SHARE_SIZE_EXCEEDED", "Gói chia sẻ vượt quá giới hạn 25 MB.", 400);
        }

        var code = await GenerateUniqueShareCodeAsync(ct);
        var expiresInDays = Math.Clamp(request.ExpiresInDays <= 0 ? 7 : request.ExpiresInDays, 1, 30);

        var payload = new SharePayloadModel(
            request.Combos,
            request.CustomScenarios,
            request.CustomAmbientSounds);

        var share = new SharePackage
        {
            Id = Guid.NewGuid(),
            Code = code,
            CreatedById = userId,
            SnapshotJson = JsonSerializer.Serialize(payload, JsonOptions),
            IncludesAudio = request.IncludeAudio,
            ComboCount = request.Combos.Count,
            SizeBytes = totalBytes,
            ImportCount = 0,
            MaxImports = request.MaxImports,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(expiresInDays)
        };

        foreach (var media in userMedia)
        {
            share.MediaItems.Add(new SharePackageMedia
            {
                SharePackageId = share.Id,
                MediaFileId = media.Id
            });
        }

        shareRepo.Add(share);
        await shareRepo.SaveChangesAsync(ct);

        return ServiceResult<ShareSummaryDto>.Success(MapShareSummary(share, payload, userMedia));
    }

    public async Task<ServiceResult<ShareSummaryDto>> GetShareByCodeAsync(string code, CancellationToken ct = default)
    {
        var normalized = ShareCodeGenerator.NormalizeCode(code);
        var share = await shareRepo.FindByCodeWithMediaAsync(normalized, asNoTracking: true, ct);
        if (share is null)
        {
            return ServiceResult<ShareSummaryDto>.Failed("SHARE_NOT_FOUND", $"Không tìm thấy mã chia sẻ '{normalized}'. Vui lòng kiểm tra lại.", 404);
        }

        if (!TryValidateShareActive(share, out var errCode, out var errMsg, out var statusCode))
        {
            return ServiceResult<ShareSummaryDto>.Failed(errCode, errMsg, statusCode);
        }

        var payload = JsonSerializer.Deserialize<SharePayloadModel>(share.SnapshotJson, JsonOptions)
            ?? new SharePayloadModel([], [], []);
        var mediaList = share.MediaItems.Where(m => m.MediaFile is not null).Select(m => m.MediaFile!).ToList();

        return ServiceResult<ShareSummaryDto>.Success(MapShareSummary(share, payload, mediaList));
    }

    public async Task<ServiceResult<ShareSummaryDto>> RecordImportAsync(string code, CancellationToken ct = default)
    {
        var normalized = ShareCodeGenerator.NormalizeCode(code);
        var share = await shareRepo.FindByCodeWithMediaAsync(normalized, asNoTracking: false, ct);
        if (share is null)
        {
            return ServiceResult<ShareSummaryDto>.Failed("SHARE_NOT_FOUND", $"Không tìm thấy mã chia sẻ '{normalized}'. Vui lòng kiểm tra lại.", 404);
        }

        if (!TryValidateShareActive(share, out var errCode, out var errMsg, out var statusCode))
        {
            return ServiceResult<ShareSummaryDto>.Failed(errCode, errMsg, statusCode);
        }

        share.ImportCount++;
        await shareRepo.SaveChangesAsync(ct);

        var payload = JsonSerializer.Deserialize<SharePayloadModel>(share.SnapshotJson, JsonOptions)
            ?? new SharePayloadModel([], [], []);
        var mediaList = share.MediaItems.Where(m => m.MediaFile is not null).Select(m => m.MediaFile!).ToList();

        return ServiceResult<ShareSummaryDto>.Success(MapShareSummary(share, payload, mediaList));
    }

    public async Task<(MediaFile Meta, Stream Stream)> OpenShareMediaAsync(
        string code,
        Guid mediaId,
        CancellationToken ct = default)
    {
        var normalized = ShareCodeGenerator.NormalizeCode(code);
        var share = await shareRepo.FindByCodeWithMediaAsync(normalized, asNoTracking: true, ct)
            ?? throw new ApiDomainException("SHARE_NOT_FOUND", $"Không tìm thấy mã chia sẻ '{normalized}'.", 404);

        ValidateShareActive(share);

        var media = share.MediaItems.FirstOrDefault(m => m.MediaFileId == mediaId)?.MediaFile
            ?? throw new ApiDomainException("MEDIA_NOT_FOUND", "File âm thanh không nằm trong gói chia sẻ này.", 404);

        var stream = await mediaStorage.OpenReadAsync(media.StorageKey, ct)
            ?? throw new ApiDomainException("MEDIA_FILE_MISSING", "File âm thanh không còn trên ổ đĩa.", 404);
        return (media, stream);
    }

    public async Task<IReadOnlyList<ShareSummaryDto>> GetMySharesAsync(Guid userId, CancellationToken ct = default)
    {
        var shares = await shareRepo.GetUserSharesWithMediaAsync(userId, ct);

        return shares.Select(s =>
        {
            var payload = JsonSerializer.Deserialize<SharePayloadModel>(s.SnapshotJson, JsonOptions)
                ?? new SharePayloadModel([], [], []);
            var mediaList = s.MediaItems.Where(m => m.MediaFile is not null).Select(m => m.MediaFile!).ToList();
            return MapShareSummary(s, payload, mediaList);
        }).ToList();
    }

    public async Task RevokeShareAsync(Guid userId, string code, CancellationToken ct = default)
    {
        var normalized = ShareCodeGenerator.NormalizeCode(code);
        var share = await shareRepo.FindUserShareByCodeAsync(userId, normalized, ct)
            ?? throw new ApiDomainException("SHARE_NOT_FOUND", "Không tìm thấy mã chia sẻ của bạn.", 404);

        share.RevokedAt = DateTime.UtcNow;
        await shareRepo.SaveChangesAsync(ct);
    }

    private async Task<string> GenerateUniqueShareCodeAsync(CancellationToken ct)
    {
        for (var attempt = 0; attempt < 10; attempt++)
        {
            var candidate = ShareCodeGenerator.GenerateCode();
            if (!await shareRepo.ExistsByCodeAsync(candidate, ct))
            {
                return candidate;
            }
        }
        throw new ApiDomainException("SHARE_CODE_GENERATION_FAILED", "Không thể tạo mã chia sẻ duy nhất.", 500);
    }

    private static bool TryValidateShareActive(SharePackage share, out string errorCode, out string errorMessage, out int statusCode)
    {
        if (share.RevokedAt is not null)
        {
            errorCode = "SHARE_REVOKED";
            errorMessage = "Mã chia sẻ này đã bị thu hồi. Vui lòng thử lại với mã khác.";
            statusCode = 410;
            return false;
        }
        if (share.ExpiresAt <= DateTime.UtcNow)
        {
            errorCode = "SHARE_EXPIRED";
            errorMessage = "Mã chia sẻ này đã hết hạn. Vui lòng thử lại với mã khác.";
            statusCode = 410;
            return false;
        }
        if (share.MaxImports.HasValue && share.ImportCount >= share.MaxImports.Value)
        {
            errorCode = "SHARE_LIMIT_REACHED";
            errorMessage = "Mã chia sẻ đã đạt giới hạn số lần nhập.";
            statusCode = 410;
            return false;
        }
        errorCode = string.Empty;
        errorMessage = string.Empty;
        statusCode = 200;
        return true;
    }

    private static void ValidateShareActive(SharePackage share)
    {
        if (!TryValidateShareActive(share, out var errCode, out var errMsg, out var statusCode))
        {
            throw new ApiDomainException(errCode, errMsg, statusCode);
        }
    }

    private static ShareSummaryDto MapShareSummary(
        SharePackage share,
        SharePayloadModel payload,
        List<MediaFile> mediaList) =>
        new(
            share.Id,
            share.Code,
            share.IncludesAudio,
            share.ComboCount,
            share.SizeBytes,
            share.ImportCount,
            share.MaxImports,
            share.CreatedAt,
            share.ExpiresAt,
            share.RevokedAt is not null,
            payload.Combos,
            payload.CustomScenarios,
            payload.CustomAmbientSounds,
            mediaList.Select(m => new MediaCheckItemDto(m.Sha256, m.Id, m.Extension, m.SizeBytes)).ToList());

    private sealed record SharePayloadModel(
        IReadOnlyList<BackupComboDto> Combos,
        IReadOnlyList<ScenarioDto> CustomScenarios,
        IReadOnlyList<AmbientSoundDto> CustomAmbientSounds);

    private static int NormalizeCallDelay(int seconds) =>
        DomainLimits.AllowedCallDelaySeconds.Contains(seconds) ? seconds : 30;

    private static ThemePreference ParseTheme(string? raw) =>
        raw?.ToLowerInvariant() == "light" ? ThemePreference.Light : ThemePreference.Dark;

    private static ScenarioCategory ParseCategory(string? raw) =>
        raw?.ToLowerInvariant() switch
        {
            "work" => ScenarioCategory.Work,
            "personal" => ScenarioCategory.Personal,
            _ => ScenarioCategory.Family
        };

    private static string MapCategoryString(ScenarioCategory category) =>
        category switch
        {
            ScenarioCategory.Work => "work",
            ScenarioCategory.Personal => "personal",
            _ => "family"
        };

    private static CallInterface ParseCallInterface(string? raw) =>
        raw?.ToLowerInvariant() switch
        {
            "zalo" => CallInterface.Zalo,
            "messenger" => CallInterface.Messenger,
            _ => CallInterface.Phone
        };

    private static string MapCallInterfaceString(CallInterface type) =>
        type switch
        {
            CallInterface.Zalo => "zalo",
            CallInterface.Messenger => "messenger",
            _ => "phone"
        };

    private static RingtoneType ParseRingtone(string? raw) =>
        raw?.ToLowerInvariant() switch
        {
            "classic" => RingtoneType.Classic,
            "custom" => RingtoneType.Custom,
            _ => RingtoneType.InterfaceDefault
        };

    private static string MapRingtoneString(RingtoneType type) =>
        type switch
        {
            RingtoneType.Classic => "classic",
            RingtoneType.Custom => "custom",
            _ => "interfaceDefault"
        };
}
