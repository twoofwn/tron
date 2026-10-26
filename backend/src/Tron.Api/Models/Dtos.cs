namespace Tron.Api.Models;

// Auth & Account
public record RegisterRequest(string Email, string Password, string DisplayName, string? DeviceName = null);
public record LoginRequest(string Email, string Password, string? DeviceName = null);
public record RefreshRequest(string RefreshToken, string? DeviceName = null);
public record LogoutRequest(string RefreshToken);
public record UpdateProfileRequest(string DisplayName);
public record ChangePasswordRequest(string CurrentPassword, string NewPassword);

public record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTime ExpiresAt,
    UserProfileDto User);

public record UserProfileDto(
    Guid Id,
    string Email,
    string DisplayName,
    string Role,
    DateTime CreatedAt,
    DateTime? LastBackupAt,
    int BackupComboCount,
    int BackupScenarioCount,
    long UsedMediaBytes,
    long QuotaMediaBytes);

// Catalog & Scenarios
public record DialogueStepDto(
    string Id,
    string Type,
    string Text,
    string? AudioPath,
    Guid? MediaFileId,
    int Seconds);

public record ScenarioDto(
    string Id,
    string Title,
    string Category,
    string Source,
    string CallerName,
    string Initial,
    int? EstimatedSeconds,
    string? DefaultBackgroundId,
    bool IsPro,
    IReadOnlyList<DialogueStepDto> Steps);

public record AmbientSoundDto(
    string Id,
    string Title,
    string IconName,
    string? AudioPath,
    Guid? MediaFileId,
    string? LegacyKey,
    bool IsCustom);

public record RingtoneDto(
    string Id,
    string Title,
    string AudioPath);

// Media
public record MediaCheckRequest(IReadOnlyList<string> Sha256List);
public record MediaCheckItemDto(string Sha256, Guid MediaId, string Extension, long SizeBytes);
public record MediaCheckResponse(
    IReadOnlyList<MediaCheckItemDto> Existing,
    IReadOnlyList<string> Missing);

public record MediaUploadResponse(
    Guid MediaId,
    string Sha256,
    string Extension,
    long SizeBytes,
    string ContentType);

// Backup & Restore
public record UserSettingsDto(
    string ThemeMode,
    int DefaultCallDelaySeconds);

public record BackupComboDto(
    Guid Id,
    string Name,
    string ScenarioId,
    string CallInterface,
    string RingtoneType,
    Guid? RingtoneMediaId,
    IReadOnlyList<string> BackgroundSoundIds,
    Guid? CustomBackgroundMediaId,
    decimal BackgroundVolume,
    bool BackgroundOverridden,
    DateTime CreatedAt);

public record BackupSnapshotRequest(
    string? DeviceName,
    string? AppVersion,
    UserSettingsDto Settings,
    IReadOnlyList<AmbientSoundDto> CustomAmbientSounds,
    IReadOnlyList<ScenarioDto> CustomScenarios,
    IReadOnlyList<BackupComboDto> Combos);

public record BackupStatusDto(
    DateTime? LastBackupAt,
    string? DeviceName,
    int ComboCount,
    int ScenarioCount,
    int AmbientCount,
    int MediaCount,
    long TotalMediaBytes,
    long QuotaMediaBytes);

public record BackupRestoreResponse(
    BackupStatusDto Status,
    UserSettingsDto Settings,
    IReadOnlyList<AmbientSoundDto> CustomAmbientSounds,
    IReadOnlyList<ScenarioDto> CustomScenarios,
    IReadOnlyList<BackupComboDto> Combos,
    IReadOnlyList<MediaCheckItemDto> MediaFiles);

// Online Sharing (EH-XXXXXX)
public record CreateShareRequest(
    IReadOnlyList<BackupComboDto> Combos,
    IReadOnlyList<ScenarioDto> CustomScenarios,
    IReadOnlyList<AmbientSoundDto> CustomAmbientSounds,
    bool IncludeAudio,
    int ExpiresInDays = 7,
    int? MaxImports = null);

public record ShareSummaryDto(
    Guid Id,
    string Code,
    bool IncludesAudio,
    int ComboCount,
    long SizeBytes,
    int ImportCount,
    int? MaxImports,
    DateTime CreatedAt,
    DateTime ExpiresAt,
    bool IsRevoked,
    IReadOnlyList<BackupComboDto> Combos,
    IReadOnlyList<ScenarioDto> CustomScenarios,
    IReadOnlyList<AmbientSoundDto> CustomAmbientSounds,
    IReadOnlyList<MediaCheckItemDto> MediaFiles);

// Direct DB User Scenarios & Ambient Sounds Bundle
public record UserScenariosBundleDto(
    IReadOnlyList<ScenarioDto> CustomScenarios,
    IReadOnlyList<AmbientSoundDto> CustomAmbientSounds);

// Situation Package Marketplace (Chợ Gói Tình Huống)
public record MarketPackageDto(
    Guid Id,
    string Code,
    Guid? SellerId,
    string SellerName,
    bool IsOfficial,
    string Title,
    string Description,
    string CategoryTag,
    int PriceVnd,
    int ComboCount,
    int ScenarioCount,
    int DownloadCount,
    decimal RatingAvg,
    bool IsPurchased,
    bool IsOwner,
    DateTime CreatedAt,
    IReadOnlyList<BackupComboDto> Combos,
    IReadOnlyList<ScenarioDto> CustomScenarios,
    IReadOnlyList<AmbientSoundDto> CustomAmbientSounds);

public record CreateMarketPackageRequest(
    string Title,
    string? Description = null,
    string? CategoryTag = null,
    int PriceVnd = 0,
    IReadOnlyList<BackupComboDto>? Combos = null,
    IReadOnlyList<ScenarioDto>? CustomScenarios = null,
    IReadOnlyList<AmbientSoundDto>? CustomAmbientSounds = null);

public record MarketPurchaseResponse(
    Guid PurchaseId,
    Guid PackageId,
    int AddedCombosCount,
    int AddedScenariosCount,
    IReadOnlyList<BackupComboDto> AddedCombos,
    IReadOnlyList<ScenarioDto> AddedScenarios);
