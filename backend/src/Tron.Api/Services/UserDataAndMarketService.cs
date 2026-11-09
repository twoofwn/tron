using System.Security.Cryptography;
using System.Text.Json;
using Tron.Api.Models;
using Tron.Api.Repositories;

namespace Tron.Api.Services;

public class UserDataService(
    UserDataRepository userDataRepo,
    UserRepository userRepo,
    MediaRepository mediaRepo)
{
    public async Task<IReadOnlyList<BackupComboDto>> GetCombosAsync(Guid userId, CancellationToken ct = default)
    {
        var combos = await userDataRepo.GetUserCombosAsync(userId, ct);

        // If newly registered user has 0 combos and no previous backup, seed the 3 starter combos into DB
        if (combos.Count == 0)
        {
            var latestBackup = await userRepo.GetLatestBackupAsync(userId, ct);
            if (latestBackup is null)
            {
                var starterCombos = CreateStarterCombos(userId);
                foreach (var sc in starterCombos)
                {
                    userDataRepo.AddCombo(sc);
                }
                // Record an initial marker backup row so deleting all combos later won't re-seed
                await userDataRepo.SaveChangesAsync(ct);
                combos = starterCombos;
            }
        }

        var prefix = $"u_{userId:N}_";
        return combos.Select(c => MapComboDto(c, prefix)).ToList();
    }

    public async Task<BackupComboDto> UpsertComboAsync(Guid userId, BackupComboDto dto, CancellationToken ct = default)
    {
        var comboId = dto.Id == Guid.Empty ? Guid.NewGuid() : dto.Id;
        var existing = await userDataRepo.FindUserComboWithBackgroundsAsync(userId, comboId, ct);
        var prefix = $"u_{userId:N}_";

        // Chỉ nhận file thuộc chính người dùng. Guid.Empty ở trường giọng nghĩa là xoá giọng.
        var ringtoneMediaId = await ResolveOwnedMediaAsync(userId, dto.RingtoneMediaId, ct);
        var customBackgroundMediaId = await ResolveOwnedMediaAsync(userId, dto.CustomBackgroundMediaId, ct);
        var voiceMediaId = await ResolveOwnedMediaAsync(userId, dto.VoiceMediaId, ct);
        var videoMediaId = await ResolveOwnedMediaAsync(userId, dto.VideoMediaId, ct);
        var avatarMediaId = await ResolveOwnedMediaAsync(userId, dto.AvatarMediaId, ct);
        var previousVoiceMediaId = existing?.VoiceMediaId;
        var previousVideoMediaId = existing?.VideoMediaId;
        var previousAvatarMediaId = existing?.AvatarMediaId;

        if (existing is null)
        {
            var count = await userDataRepo.CountUserCombosAsync(userId, ct);
            if (count >= DomainLimits.MaxUserCombos)
            {
                throw new ApiDomainException("COMBO_LIMIT_EXCEEDED", $"Số lượng combo tối đa là {DomainLimits.MaxUserCombos}.");
            }

            existing = new Combo
            {
                Id = comboId,
                OwnerId = userId,
                Name = string.IsNullOrWhiteSpace(dto.Name) ? "Combo" : dto.Name.Trim(),
                ScenarioId = dto.ScenarioId,
                CallInterface = ParseCallInterface(dto.CallInterface),
                RingtoneType = ParseRingtone(dto.RingtoneType),
                RingtoneMediaId = ringtoneMediaId,
                CustomBackgroundMediaId = customBackgroundMediaId,
                VoiceMediaId = voiceMediaId,
                CallType = ParseCallType(dto.CallType) ?? CallType.Voice,
                VideoMediaId = videoMediaId,
                AvatarMediaId = avatarMediaId,
                CallerName = CleanCallerName(dto.CallerName),
                VideoEndAction = ParseVideoEndAction(dto.VideoEndAction) ?? VideoEndAction.HangUp,
                BackgroundVolume = Math.Clamp(dto.BackgroundVolume <= 0 ? 0.3m : dto.BackgroundVolume, 0m, 1m),
                BackgroundOverridden = dto.BackgroundOverridden,
                SortOrder = count + 1,
                CreatedAt = dto.CreatedAt == default ? DateTime.UtcNow : dto.CreatedAt,
                UpdatedAt = DateTime.UtcNow
            };

            var bgOrder = 1;
            foreach (var bgId in dto.BackgroundSoundIds.Distinct())
            {
                if (!string.IsNullOrWhiteSpace(bgId) && !bgId.Equals("none", StringComparison.OrdinalIgnoreCase))
                {
                    existing.Backgrounds.Add(new ComboBackground
                    {
                        OwnerId = userId,
                        ComboId = comboId,
                        AmbientSoundId = bgId,
                        Order = bgOrder++
                    });
                }
            }

            userDataRepo.AddCombo(existing);
        }
        else
        {
            existing.Name = string.IsNullOrWhiteSpace(dto.Name) ? "Combo" : dto.Name.Trim();
            existing.ScenarioId = dto.ScenarioId;
            existing.CallInterface = ParseCallInterface(dto.CallInterface);
            existing.RingtoneType = ParseRingtone(dto.RingtoneType);
            existing.RingtoneMediaId = ringtoneMediaId;
            existing.CustomBackgroundMediaId = customBackgroundMediaId;
            // Không gửi trường này (app bản cũ) thì giữ nguyên; Guid.Empty nghĩa là người dùng đã xoá giọng.
            if (dto.VoiceMediaId.HasValue)
            {
                existing.VoiceMediaId = voiceMediaId;
            }
            // Cùng quy ước cho loại cuộc gọi và video: không gửi = giữ nguyên.
            existing.CallType = ParseCallType(dto.CallType) ?? existing.CallType;
            if (dto.VideoMediaId.HasValue)
            {
                existing.VideoMediaId = videoMediaId;
            }
            if (dto.AvatarMediaId.HasValue)
            {
                existing.AvatarMediaId = avatarMediaId;
            }
            // App bản mới luôn gửi VideoEndAction (kể cả khi tên người gọi rỗng).
            if (ParseVideoEndAction(dto.VideoEndAction) is { } endAction)
            {
                existing.VideoEndAction = endAction;
                existing.CallerName = CleanCallerName(dto.CallerName);
            }
            existing.BackgroundVolume = Math.Clamp(dto.BackgroundVolume <= 0 ? 0.3m : dto.BackgroundVolume, 0m, 1m);
            existing.BackgroundOverridden = dto.BackgroundOverridden;
            existing.UpdatedAt = DateTime.UtcNow;

            userDataRepo.RemoveComboBackgrounds(existing.Backgrounds);
            await userDataRepo.SaveChangesAsync(ct);
            existing.Backgrounds.Clear();

            var bgOrder = 1;
            foreach (var bgId in dto.BackgroundSoundIds.Distinct())
            {
                if (!string.IsNullOrWhiteSpace(bgId) && !bgId.Equals("none", StringComparison.OrdinalIgnoreCase))
                {
                    existing.Backgrounds.Add(new ComboBackground
                    {
                        OwnerId = userId,
                        ComboId = comboId,
                        AmbientSoundId = bgId,
                        Order = bgOrder++
                    });
                }
            }
        }

        await userDataRepo.SaveChangesAsync(ct);

        // Giọng cũ bị thay hoặc xoá: đánh dấu để dọn, khỏi chiếm hạn mức.
        if (previousVoiceMediaId.HasValue && previousVoiceMediaId != existing.VoiceMediaId)
        {
            await mediaRepo.OrphanIfUnreferencedAsync(userId, previousVoiceMediaId.Value, ct);
        }
        if (previousVideoMediaId.HasValue && previousVideoMediaId != existing.VideoMediaId)
        {
            await mediaRepo.OrphanIfUnreferencedAsync(userId, previousVideoMediaId.Value, ct);
        }
        if (previousAvatarMediaId.HasValue && previousAvatarMediaId != existing.AvatarMediaId)
        {
            await mediaRepo.OrphanIfUnreferencedAsync(userId, previousAvatarMediaId.Value, ct);
        }

        return MapComboDto(existing, prefix);
    }

    /// <summary>
    /// null hoặc Guid.Empty → null. Id khác phải là file của chính người dùng (bỏ dấu mồ côi nếu có), nếu không thì báo lỗi 400.
    /// </summary>
    private async Task<Guid?> ResolveOwnedMediaAsync(Guid userId, Guid? mediaId, CancellationToken ct)
    {
        if (mediaId is null || mediaId == Guid.Empty)
        {
            return null;
        }

        var media = await mediaRepo.FindOwnedMediaTrackedAsync(userId, mediaId.Value, ct)
            ?? throw new ApiDomainException("MEDIA_NOT_FOUND", "File âm thanh không tồn tại hoặc không thuộc tài khoản này.");
        media.OrphanedAt = null;
        return media.Id;
    }

    public async Task DeleteComboAsync(Guid userId, Guid comboId, CancellationToken ct = default)
    {
        var existing = await userDataRepo.FindUserComboWithBackgroundsAsync(userId, comboId, ct);
        if (existing is null)
        {
            return;
        }

        var voiceMediaId = existing.VoiceMediaId;
        var videoMediaId = existing.VideoMediaId;
        var avatarMediaId = existing.AvatarMediaId;
        userDataRepo.RemoveCombo(existing);
        await userDataRepo.SaveChangesAsync(ct);
        if (voiceMediaId.HasValue)
        {
            await mediaRepo.OrphanIfUnreferencedAsync(userId, voiceMediaId.Value, ct);
        }
        if (videoMediaId.HasValue)
        {
            await mediaRepo.OrphanIfUnreferencedAsync(userId, videoMediaId.Value, ct);
        }
        if (avatarMediaId.HasValue)
        {
            await mediaRepo.OrphanIfUnreferencedAsync(userId, avatarMediaId.Value, ct);
        }
    }

    public async Task<UserScenariosBundleDto> GetUserScenariosBundleAsync(Guid userId, CancellationToken ct = default)
    {
        var scenarios = await userDataRepo.GetUserScenariosAsync(userId, ct);
        var ambients = await userDataRepo.GetUserAmbientSoundsAsync(userId, ct);
        var prefix = $"u_{userId:N}_";

        return new UserScenariosBundleDto(
            scenarios.Select(s => MapScenarioDto(s, prefix)).ToList(),
            ambients.Select(a => MapAmbientDto(a, prefix)).ToList());
    }

    public async Task<ScenarioDto> UpsertUserScenarioAsync(Guid userId, ScenarioDto dto, CancellationToken ct = default)
    {
        var prefix = $"u_{userId:N}_";
        var scopedId = BuildScopedScenarioId(userId, dto.Id);

        var existing = await userDataRepo.FindUserScenarioWithStepsAsync(userId, scopedId, ct);
        if (existing is null)
        {
            var count = await userDataRepo.CountUserScenariosAsync(userId, ct);
            if (count >= DomainLimits.MaxUserScenarios)
            {
                throw new ApiDomainException("SCENARIO_LIMIT_EXCEEDED", $"Số lượng kịch bản cá nhân tối đa là {DomainLimits.MaxUserScenarios}.");
            }

            existing = new Scenario
            {
                Id = scopedId,
                OwnerId = userId,
                Title = string.IsNullOrWhiteSpace(dto.Title) ? "Kịch bản cá nhân" : dto.Title.Trim(),
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

            PopulateSteps(existing, scopedId, dto.Steps);
            userDataRepo.AddScenario(existing);
        }
        else
        {
            existing.Title = string.IsNullOrWhiteSpace(dto.Title) ? "Kịch bản cá nhân" : dto.Title.Trim();
            existing.Category = ParseCategory(dto.Category);
            existing.CallerName = string.IsNullOrWhiteSpace(dto.CallerName) ? "Người gọi" : dto.CallerName.Trim();
            existing.Initial = string.IsNullOrWhiteSpace(dto.Initial) ? "N" : dto.Initial.Trim()[..1].ToUpperInvariant();
            existing.EstimatedSeconds = dto.EstimatedSeconds;
            existing.DefaultAmbientSoundId = dto.DefaultBackgroundId;
            existing.UpdatedAt = DateTime.UtcNow;

            userDataRepo.RemoveDialogueSteps(existing.Steps);
            await userDataRepo.SaveChangesAsync(ct);
            existing.Steps.Clear();
            PopulateSteps(existing, scopedId, dto.Steps);
        }

        await userDataRepo.SaveChangesAsync(ct);
        return MapScenarioDto(existing, prefix);
    }

    private static string BuildScopedScenarioId(Guid userId, string? rawId)
    {
        var cleanRaw = string.IsNullOrWhiteSpace(rawId) ? $"c_{Guid.NewGuid():N}" : rawId.Trim();
        var prefix = $"u_{userId:N}_";
        if (cleanRaw.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            cleanRaw = cleanRaw[prefix.Length..];
        }
        if (cleanRaw.Length > 20)
        {
            var hash = Convert.ToHexStringLower(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(cleanRaw)))[..6];
            cleanRaw = $"{cleanRaw[..12]}_{hash}";
        }
        return $"{prefix}{cleanRaw}";
    }

    public async Task DeleteUserScenarioAsync(Guid userId, string id, CancellationToken ct = default)
    {
        var prefix = $"u_{userId:N}_";
        var scopedId = id.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? id : $"{prefix}{id}";
        var existing = await userDataRepo.FindUserScenarioWithStepsAsync(userId, scopedId, ct);
        if (existing is null)
        {
            return;
        }

        userDataRepo.RemoveDialogueSteps(existing.Steps);
        userDataRepo.RemoveScenario(existing);
        await userDataRepo.SaveChangesAsync(ct);
    }

    public async Task<AmbientSoundDto> UpsertUserAmbientSoundAsync(Guid userId, AmbientSoundDto dto, CancellationToken ct = default)
    {
        var prefix = $"u_{userId:N}_";
        var rawId = string.IsNullOrWhiteSpace(dto.Id) ? $"custom-bg-{Guid.NewGuid():N}" : dto.Id.Trim();
        var scopedId = rawId.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? rawId : $"{prefix}{rawId}";

        var existing = await userDataRepo.FindUserAmbientSoundAsync(userId, scopedId, ct);
        if (existing is null)
        {
            existing = new AmbientSound
            {
                Id = scopedId,
                OwnerId = userId,
                Title = string.IsNullOrWhiteSpace(dto.Title) ? "Âm nền riêng" : dto.Title.Trim(),
                IconName = string.IsNullOrWhiteSpace(dto.IconName) ? "music" : dto.IconName.Trim(),
                AssetAudioPath = dto.AudioPath,
                MediaFileId = dto.MediaFileId,
                LegacyKey = rawId,
                SortOrder = 100,
                CreatedAt = DateTime.UtcNow
            };
            userDataRepo.AddAmbientSound(existing);
        }
        else
        {
            existing.Title = string.IsNullOrWhiteSpace(dto.Title) ? "Âm nền riêng" : dto.Title.Trim();
            existing.IconName = string.IsNullOrWhiteSpace(dto.IconName) ? "music" : dto.IconName.Trim();
            existing.AssetAudioPath = dto.AudioPath;
            existing.MediaFileId = dto.MediaFileId;
        }

        await userDataRepo.SaveChangesAsync(ct);
        return MapAmbientDto(existing, prefix);
    }

    public async Task DeleteUserAmbientSoundAsync(Guid userId, string id, CancellationToken ct = default)
    {
        var prefix = $"u_{userId:N}_";
        var scopedId = id.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? id : $"{prefix}{id}";
        var existing = await userDataRepo.FindUserAmbientSoundAsync(userId, scopedId, ct);
        if (existing is null)
        {
            return;
        }

        userDataRepo.RemoveAmbientSound(existing);
        await userDataRepo.SaveChangesAsync(ct);
    }

    public async Task<UserSettingsDto> UpdateUserSettingsAsync(Guid userId, UserSettingsDto dto, CancellationToken ct = default)
    {
        var settings = await userDataRepo.GetUserSettingsAsync(userId, ct);
        var theme = dto.ThemeMode?.ToLowerInvariant() == "light" ? ThemePreference.Light : ThemePreference.Dark;
        var delay = DomainLimits.AllowedCallDelaySeconds.Contains(dto.DefaultCallDelaySeconds)
            ? dto.DefaultCallDelaySeconds
            : 30;

        if (settings is null)
        {
            settings = new UserSettings
            {
                UserId = userId,
                ThemeMode = theme,
                DefaultCallDelaySeconds = delay,
                UpdatedAt = DateTime.UtcNow
            };
            userDataRepo.AddUserSettings(settings);
        }
        else
        {
            settings.ThemeMode = theme;
            settings.DefaultCallDelaySeconds = delay;
            settings.UpdatedAt = DateTime.UtcNow;
        }

        await userDataRepo.SaveChangesAsync(ct);
        return new UserSettingsDto(settings.ThemeMode.ToString().ToLowerInvariant(), settings.DefaultCallDelaySeconds);
    }

    private static void PopulateSteps(Scenario scenario, string scopedId, IReadOnlyList<DialogueStepDto> stepDtos)
    {
        var order = 1;
        foreach (var st in stepDtos)
        {
            var isWait = st.Type.Equals("wait", StringComparison.OrdinalIgnoreCase) ||
                         st.Type.Equals("waitForUser", StringComparison.OrdinalIgnoreCase);

            scenario.Steps.Add(new DialogueStep
            {
                Id = $"{scopedId}-s{order}",
                ScenarioId = scopedId,
                Order = order++,
                Type = isWait ? DialogueStepType.Wait : DialogueStepType.Speech,
                Text = st.Text ?? string.Empty,
                AssetAudioPath = st.AudioPath,
                MediaFileId = st.MediaFileId,
                Seconds = Math.Max(0, st.Seconds)
            });
        }
    }

    private static List<Combo> CreateStarterCombos(Guid userId)
    {
        var c1 = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = "Người yêu gọi",
            ScenarioId = "friend",
            CallInterface = CallInterface.Zalo,
            RingtoneType = RingtoneType.InterfaceDefault,
            BackgroundVolume = 0.30m,
            SortOrder = 1,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        var c2 = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = "Bố gọi",
            ScenarioId = "mother",
            CallInterface = CallInterface.Zalo,
            RingtoneType = RingtoneType.InterfaceDefault,
            BackgroundVolume = 0.30m,
            SortOrder = 2,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        c2.Backgrounds.Add(new ComboBackground { OwnerId = userId, ComboId = c2.Id, AmbientSoundId = "television", Order = 1 });

        var c3 = new Combo
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = "Anh trai gọi (Tình huống đường vắng)",
            ScenarioId = "boss",
            CallInterface = CallInterface.Zalo,
            RingtoneType = RingtoneType.InterfaceDefault,
            BackgroundVolume = 0.30m,
            SortOrder = 3,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        c3.Backgrounds.Add(new ComboBackground { OwnerId = userId, ComboId = c3.Id, AmbientSoundId = "traffic", Order = 1 });

        // Ba combo sau không có âm nền, chuông theo giao diện Zalo.
        Combo Quiet(string name, string scenarioId, int order) => new()
        {
            Id = Guid.NewGuid(),
            OwnerId = userId,
            Name = name,
            ScenarioId = scenarioId,
            CallInterface = CallInterface.Zalo,
            RingtoneType = RingtoneType.InterfaceDefault,
            BackgroundVolume = 0.30m,
            SortOrder = order,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        return
        [
            c1, c2, c3,
            Quiet("Chủ nợ gọi", "debt-collector", 4),
            Quiet("Có người lạ vào trọ", "stranger-at-home", 5),
            Quiet("Bạn đến đón", "friend-pickup", 6),
        ];
    }

    internal static BackupComboDto MapComboDto(Combo c, string prefix) =>
        new(
            c.Id,
            c.Name,
            c.ScenarioId.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? c.ScenarioId[prefix.Length..] : c.ScenarioId,
            c.CallInterface switch
            {
                CallInterface.Zalo => "zalo",
                CallInterface.Messenger => "messenger",
                _ => "phone"
            },
            c.RingtoneType switch
            {
                RingtoneType.Classic => "classic",
                RingtoneType.Custom => "custom",
                _ => "interfaceDefault"
            },
            c.RingtoneMediaId,
            c.Backgrounds.OrderBy(b => b.Order).Select(b => b.AmbientSoundId).ToList(),
            c.CustomBackgroundMediaId,
            c.BackgroundVolume,
            c.BackgroundOverridden,
            c.CreatedAt,
            c.VoiceMediaId,
            MapCallTypeString(c.CallType),
            c.VideoMediaId,
            c.CallerName,
            MapVideoEndActionString(c.VideoEndAction),
            c.AvatarMediaId);

    internal static ScenarioDto MapScenarioDto(Scenario s, string prefix) =>
        new(
            s.Id.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? s.Id[prefix.Length..] : s.Id,
            s.Title,
            s.Category switch
            {
                ScenarioCategory.Work => "work",
                ScenarioCategory.Personal => "personal",
                _ => "family"
            },
            "user",
            s.CallerName,
            s.Initial,
            s.EstimatedSeconds,
            s.DefaultAmbientSoundId,
            s.IsPro,
            s.Steps.OrderBy(st => st.Order).Select(st => new DialogueStepDto(
                st.Id,
                st.Type == DialogueStepType.Wait ? "wait" : "speech",
                st.Text,
                st.AssetAudioPath,
                st.MediaFileId,
                st.Seconds)).ToList());

    internal static AmbientSoundDto MapAmbientDto(AmbientSound a, string prefix) =>
        new(
            a.LegacyKey ?? (a.Id.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ? a.Id[prefix.Length..] : a.Id),
            a.Title,
            a.IconName,
            a.AssetAudioPath,
            a.MediaFileId,
            a.LegacyKey,
            true);

    internal static ScenarioCategory ParseCategory(string? raw) =>
        raw?.ToLowerInvariant() switch
        {
            "work" => ScenarioCategory.Work,
            "personal" => ScenarioCategory.Personal,
            _ => ScenarioCategory.Family
        };

    internal static CallInterface ParseCallInterface(string? raw) =>
        raw?.ToLowerInvariant() switch
        {
            "zalo" => CallInterface.Zalo,
            "messenger" => CallInterface.Messenger,
            _ => CallInterface.Phone
        };

    /// <summary>null khi app không gửi loại cuộc gọi (bản cũ), để nơi gọi tự quyết giữ nguyên hay dùng mặc định.</summary>
    internal static CallType? ParseCallType(string? raw) =>
        raw?.Trim().ToLowerInvariant() switch
        {
            null or "" => null,
            "video" => CallType.Video,
            _ => CallType.Voice
        };

    internal static string MapCallTypeString(CallType type) =>
        type == CallType.Video ? "video" : "voice";

    /// <summary>null khi app không gửi (bản cũ), để nơi gọi giữ nguyên giá trị đang có.</summary>
    internal static VideoEndAction? ParseVideoEndAction(string? raw) =>
        raw?.Trim().ToLowerInvariant() switch
        {
            null or "" => null,
            "loop" => VideoEndAction.Loop,
            _ => VideoEndAction.HangUp
        };

    internal static string MapVideoEndActionString(VideoEndAction action) =>
        action == VideoEndAction.Loop ? "loop" : "hangUp";

    internal static string? CleanCallerName(string? raw)
    {
        var name = raw?.Trim();
        if (string.IsNullOrEmpty(name))
        {
            return null;
        }
        return name.Length > DomainLimits.MaxCallerNameLength ? name[..DomainLimits.MaxCallerNameLength] : name;
    }

    internal static RingtoneType ParseRingtone(string? raw) =>
        raw?.ToLowerInvariant() switch
        {
            "classic" => RingtoneType.Classic,
            "custom" => RingtoneType.Custom,
            _ => RingtoneType.InterfaceDefault
        };
}

public class MarketService(
    MarketRepository marketRepo,
    UserRepository userRepo,
    UserDataService userDataService)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Converters = { new FlexibleGuidJsonConverter() }
    };

    public async Task<IReadOnlyList<MarketPackageDto>> GetPackagesAsync(
        Guid userId,
        string? filter,
        string? search,
        CancellationToken ct = default)
    {
        var packages = await marketRepo.GetPublishedPackagesAsync(ct);
        var purchasedIds = (await marketRepo.GetPurchasedPackageIdsAsync(userId, ct)).ToHashSet();

        var normalizedFilter = (filter ?? "all").Trim().ToLowerInvariant();
        var filtered = normalizedFilter switch
        {
            "official" => packages.Where(p => p.IsOfficial),
            "community" => packages.Where(p => !p.IsOfficial),
            "mine" => packages.Where(p => p.SellerId == userId || purchasedIds.Contains(p.Id)),
            "purchased" => packages.Where(p => purchasedIds.Contains(p.Id)),
            _ => packages.AsEnumerable()
        };

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim();
            filtered = filtered.Where(p =>
                p.Title.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                p.Description.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                p.SellerName.Contains(q, StringComparison.OrdinalIgnoreCase) ||
                p.CategoryTag.Contains(q, StringComparison.OrdinalIgnoreCase));
        }

        return filtered.Select(p => MapMarketPackageDto(p, userId, purchasedIds)).ToList();
    }

    public async Task<MarketPackageDto> GetPackageByIdAsync(Guid userId, Guid packageId, CancellationToken ct = default)
    {
        var package = await marketRepo.FindByIdAsync(packageId, asNoTracking: true, ct)
            ?? throw new ApiDomainException("MARKET_PACKAGE_NOT_FOUND", "Không tìm thấy gói tình huống trên Chợ.", 404);

        var purchasedIds = (await marketRepo.GetPurchasedPackageIdsAsync(userId, ct)).ToHashSet();
        return MapMarketPackageDto(package, userId, purchasedIds);
    }

    public async Task<ServiceResult<MarketPackageDto>> PublishPackageAsync(
        Guid userId,
        CreateMarketPackageRequest request,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Title) || request.Title.Trim().Length > 100)
        {
            return ServiceResult<MarketPackageDto>.Failed("MARKET_INVALID_TITLE", "Tên gói phải từ 1 đến 100 ký tự. Vui lòng nhập lại.", 400);
        }
        var combos = request.Combos ?? [];
        if (combos.Count == 0)
        {
            return ServiceResult<MarketPackageDto>.Failed("MARKET_EMPTY_COMBOS", "Chọn ít nhất 1 combo để đăng lên Chợ.", 400);
        }

        var user = await userRepo.FindByIdAsync(userId, onlyActive: true, ct);
        if (user is null)
        {
            return ServiceResult<MarketPackageDto>.Failed("USER_NOT_FOUND", "Không tìm thấy tài khoản.", 404);
        }

        var code = await GenerateUniqueMarketCodeAsync(ct);
        var customScenarios = request.CustomScenarios ?? [];
        var customAmbientSounds = request.CustomAmbientSounds ?? [];
        var payload = new MarketPayloadModel(
            combos,
            customScenarios,
            customAmbientSounds);

        var isOfficial = user.Role == UserRole.Admin;
        var package = new MarketPackage
        {
            Id = Guid.NewGuid(),
            Code = code,
            SellerId = userId,
            SellerName = isOfficial ? "TRỐN Official" : user.DisplayName,
            IsOfficial = isOfficial,
            Title = request.Title.Trim(),
            Description = string.IsNullOrWhiteSpace(request.Description)
                ? $"Gói {combos.Count} combo tình huống được chia sẻ bởi {user.DisplayName}."
                : request.Description.Trim(),
            CategoryTag = string.IsNullOrWhiteSpace(request.CategoryTag) ? "Cộng đồng" : request.CategoryTag.Trim(),
            PriceVnd = 0,
            ComboCount = combos.Count,
            ScenarioCount = customScenarios.Count,
            DownloadCount = 0,
            RatingAvg = 5.00m,
            PayloadJson = JsonSerializer.Serialize(payload, JsonOptions),
            IsPublished = true,
            CreatedAt = DateTime.UtcNow
        };

        marketRepo.AddPackage(package);
        await marketRepo.SaveChangesAsync(ct);

        return ServiceResult<MarketPackageDto>.Success(MapMarketPackageDto(package, userId, []));
    }

    public async Task<ServiceResult<MarketPurchaseResponse>> PurchaseOrClaimPackageAsync(
        Guid userId,
        Guid packageId,
        CancellationToken ct = default)
    {
        var package = await marketRepo.FindByIdAsync(packageId, asNoTracking: false, ct);
        if (package is null)
        {
            return ServiceResult<MarketPurchaseResponse>.Failed("MARKET_PACKAGE_NOT_FOUND", "Không tìm thấy gói tình huống trên Chợ.", 404);
        }

        var existingPurchase = await marketRepo.FindPurchaseAsync(packageId, userId, ct);
        if (existingPurchase is null)
        {
            existingPurchase = new MarketPurchase
            {
                Id = Guid.NewGuid(),
                MarketPackageId = packageId,
                BuyerId = userId,
                PricePaidVnd = 0,
                PurchasedAt = DateTime.UtcNow
            };
            marketRepo.AddPurchase(existingPurchase);
            package.DownloadCount++;
            await marketRepo.SaveChangesAsync(ct);
        }

        var payload = JsonSerializer.Deserialize<MarketPayloadModel>(package.PayloadJson, JsonOptions)
            ?? new MarketPayloadModel([], [], []);

        // 1. Save custom scenarios from the package directly into the buyer's Scenarios table in SQL Server
        var addedScenarios = new List<ScenarioDto>();
        foreach (var sc in payload.CustomScenarios)
        {
            try
            {
                var savedSc = await userDataService.UpsertUserScenarioAsync(userId, sc, ct);
                addedScenarios.Add(savedSc);
            }
            catch
            {
                // Continue adding other scenarios if one fails
            }
        }

        // 2. Save combos from the package directly into the buyer's Combos table in SQL Server
        var addedCombos = new List<BackupComboDto>();
        foreach (var combo in payload.Combos)
        {
            try
            {
                // File âm thanh/video riêng thuộc người bán: người mua không dùng được, dùng chuông/giọng mặc định.
                var newComboDto = combo with
                {
                    Id = Guid.NewGuid(),
                    CreatedAt = DateTime.UtcNow,
                    RingtoneMediaId = null,
                    CustomBackgroundMediaId = null,
                    VoiceMediaId = null,
                    VideoMediaId = null,
                    AvatarMediaId = null
                };
                var savedCombo = await userDataService.UpsertComboAsync(userId, newComboDto, ct);
                addedCombos.Add(savedCombo);
            }
            catch
            {
                // Continue adding other combos if one fails
            }
        }

        return ServiceResult<MarketPurchaseResponse>.Success(new MarketPurchaseResponse(
            existingPurchase.Id,
            package.Id,
            addedCombos.Count,
            addedScenarios.Count,
            addedCombos,
            addedScenarios));
    }

    public async Task<ServiceResult> DeletePackageAsync(Guid userId, Guid packageId, CancellationToken ct = default)
    {
        var package = await marketRepo.FindByIdAsync(packageId, asNoTracking: false, ct);
        if (package is null)
        {
            return ServiceResult.Failed("MARKET_PACKAGE_NOT_FOUND", "Không tìm thấy gói tình huống.", 404);
        }

        if (package.SellerId != userId)
        {
            return ServiceResult.Failed("FORBIDDEN", "Bạn chỉ có thể gỡ gói do chính mình đăng.", 403);
        }

        marketRepo.RemovePackage(package);
        await marketRepo.SaveChangesAsync(ct);
        return ServiceResult.Success();
    }

    private async Task<string> GenerateUniqueMarketCodeAsync(CancellationToken ct)
    {
        const string alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
        for (var attempt = 0; attempt < 10; attempt++)
        {
            var bytes = RandomNumberGenerator.GetBytes(6);
            var chars = new char[6];
            for (var i = 0; i < 6; i++)
            {
                chars[i] = alphabet[bytes[i] & 31];
            }
            var code = $"MKT-{new string(chars)}";
            if (!await marketRepo.ExistsByCodeAsync(code, ct))
            {
                return code;
            }
        }
        return $"MKT-{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}";
    }

    private static MarketPackageDto MapMarketPackageDto(
        MarketPackage p,
        Guid userId,
        HashSet<Guid> purchasedIds)
    {
        var payload = JsonSerializer.Deserialize<MarketPayloadModel>(p.PayloadJson, JsonOptions)
            ?? new MarketPayloadModel([], [], []);

        return new MarketPackageDto(
            p.Id,
            p.Code,
            p.SellerId,
            p.SellerName,
            p.IsOfficial,
            p.Title,
            p.Description,
            p.CategoryTag,
            0,
            p.ComboCount,
            p.ScenarioCount,
            p.DownloadCount,
            p.RatingAvg,
            purchasedIds.Contains(p.Id) || p.SellerId == userId,
            p.SellerId == userId,
            p.CreatedAt,
            payload.Combos,
            payload.CustomScenarios,
            payload.CustomAmbientSounds);
    }

    private sealed record MarketPayloadModel(
        IReadOnlyList<BackupComboDto> Combos,
        IReadOnlyList<ScenarioDto> CustomScenarios,
        IReadOnlyList<AmbientSoundDto> CustomAmbientSounds);
}
