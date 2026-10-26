namespace Tron.Api.Models;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string NormalizedEmail { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public UserRole Role { get; set; } = UserRole.User;
    public bool IsActive { get; set; } = true;
    public int FailedLoginCount { get; set; }
    public DateTime? LockoutEnd { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAt { get; set; }

    public UserSettings? Settings { get; set; }
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public ICollection<MediaFile> MediaFiles { get; set; } = new List<MediaFile>();
    public ICollection<Scenario> Scenarios { get; set; } = new List<Scenario>();
    public ICollection<AmbientSound> AmbientSounds { get; set; } = new List<AmbientSound>();
    public ICollection<Combo> Combos { get; set; } = new List<Combo>();
    public ICollection<Backup> Backups { get; set; } = new List<Backup>();
    public ICollection<SharePackage> SharePackages { get; set; } = new List<SharePackage>();
    public ICollection<Entitlement> Entitlements { get; set; } = new List<Entitlement>();
}

public class RefreshToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public string DeviceName { get; set; } = "Unknown";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public Guid? ReplacedById { get; set; }

    public User? User { get; set; }
}

public class UserSettings
{
    public Guid UserId { get; set; }
    public ThemePreference ThemeMode { get; set; } = ThemePreference.Dark;
    public int DefaultCallDelaySeconds { get; set; } = 30;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
}

public class MediaFile
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? OwnerId { get; set; }
    public MediaKind Kind { get; set; }
    public string OriginalName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public string Extension { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public string Sha256 { get; set; } = string.Empty;
    public string StorageKey { get; set; } = string.Empty;
    public string? AssetKey { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? OrphanedAt { get; set; }

    public User? Owner { get; set; }
}

public class Scenario
{
    public string Id { get; set; } = string.Empty;
    public Guid? OwnerId { get; set; }
    public string Title { get; set; } = string.Empty;
    public ScenarioCategory Category { get; set; }
    public ScenarioSource Source { get; set; }
    public string CallerName { get; set; } = string.Empty;
    public string Initial { get; set; } = string.Empty;
    public int? EstimatedSeconds { get; set; }
    public string? DefaultAmbientSoundId { get; set; }
    public bool IsPro { get; set; }
    public string? CopiedFromScenarioId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? Owner { get; set; }
    public ICollection<DialogueStep> Steps { get; set; } = new List<DialogueStep>();
}

public class DialogueStep
{
    public string Id { get; set; } = string.Empty;
    public string ScenarioId { get; set; } = string.Empty;
    public int Order { get; set; }
    public DialogueStepType Type { get; set; }
    public string Text { get; set; } = string.Empty;
    public Guid? MediaFileId { get; set; }
    public string? AssetAudioPath { get; set; }
    public int Seconds { get; set; }

    public Scenario? Scenario { get; set; }
    public MediaFile? MediaFile { get; set; }
}

public class ScenarioAlias
{
    public string LegacyId { get; set; } = string.Empty;
    public string ScenarioId { get; set; } = string.Empty;
    public string? FallbackTitle { get; set; }
    public string? FallbackCaller { get; set; }
    public string? FallbackDialogue { get; set; }
}

public class AmbientSound
{
    public string Id { get; set; } = string.Empty;
    public Guid? OwnerId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string IconName { get; set; } = "music";
    public Guid? MediaFileId { get; set; }
    public string? AssetAudioPath { get; set; }
    public string? LegacyKey { get; set; }
    public int SortOrder { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User? Owner { get; set; }
    public MediaFile? MediaFile { get; set; }
}

public class Ringtone
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string AssetAudioPath { get; set; } = string.Empty;
    public int SortOrder { get; set; }
}

public class Combo
{
    public Guid Id { get; set; }
    public Guid OwnerId { get; set; }
    public string Title => Name;
    public string Name { get; set; } = string.Empty;
    public string ScenarioId { get; set; } = string.Empty;
    public CallInterface CallInterface { get; set; }
    public RingtoneType RingtoneType { get; set; } = RingtoneType.InterfaceDefault;
    public Guid? RingtoneMediaId { get; set; }
    public Guid? CustomBackgroundMediaId { get; set; }
    public decimal BackgroundVolume { get; set; } = 0.30m;
    public bool BackgroundOverridden { get; set; }
    public int SortOrder { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? Owner { get; set; }
    public MediaFile? RingtoneMedia { get; set; }
    public MediaFile? CustomBackgroundMedia { get; set; }
    public ICollection<ComboBackground> Backgrounds { get; set; } = new List<ComboBackground>();
}

public class ComboBackground
{
    public Guid OwnerId { get; set; }
    public Guid ComboId { get; set; }
    public string AmbientSoundId { get; set; } = string.Empty;
    public int Order { get; set; }

    public Combo? Combo { get; set; }
}

public class Backup
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string DeviceName { get; set; } = "Unknown";
    public string AppVersion { get; set; } = "1.0.0";
    public int ComboCount { get; set; }
    public int ScenarioCount { get; set; }
    public int AmbientCount { get; set; }
    public int MediaCount { get; set; }
    public long TotalMediaBytes { get; set; }

    public User? User { get; set; }
}

public class SharePackage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Code { get; set; } = string.Empty;
    public Guid CreatedById { get; set; }
    public string SnapshotJson { get; set; } = string.Empty;
    public bool IncludesAudio { get; set; }
    public int ComboCount { get; set; }
    public long SizeBytes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
    public int? MaxImports { get; set; }
    public int ImportCount { get; set; }
    public DateTime? RevokedAt { get; set; }

    public User? CreatedBy { get; set; }
    public ICollection<SharePackageMedia> MediaItems { get; set; } = new List<SharePackageMedia>();
}

public class SharePackageMedia
{
    public Guid SharePackageId { get; set; }
    public Guid MediaFileId { get; set; }

    public SharePackage? SharePackage { get; set; }
    public MediaFile? MediaFile { get; set; }
}

public class Entitlement
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Product { get; set; } = "Pro";
    public string Source { get; set; } = "Manual";
    public DateTime StartsAt { get; set; } = DateTime.UtcNow;
    public DateTime? EndsAt { get; set; }

    public User? User { get; set; }
}

public class MarketPackage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Code { get; set; } = string.Empty;
    public Guid? SellerId { get; set; }
    public string SellerName { get; set; } = string.Empty;
    public bool IsOfficial { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string CategoryTag { get; set; } = string.Empty;
    public int PriceVnd { get; set; }
    public int ComboCount { get; set; }
    public int ScenarioCount { get; set; }
    public int DownloadCount { get; set; }
    public decimal RatingAvg { get; set; } = 5.00m;
    public string PayloadJson { get; set; } = string.Empty;
    public bool IsPublished { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User? Seller { get; set; }
    public ICollection<MarketPurchase> Purchases { get; set; } = new List<MarketPurchase>();
}

public class MarketPurchase
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid MarketPackageId { get; set; }
    public Guid BuyerId { get; set; }
    public int PricePaidVnd { get; set; }
    public DateTime PurchasedAt { get; set; } = DateTime.UtcNow;

    public MarketPackage? MarketPackage { get; set; }
    public User? Buyer { get; set; }
}
