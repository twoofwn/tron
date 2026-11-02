namespace Tron.Api.Models;

public class DomainLimitOptions
{
    public const string SectionName = "DomainLimits";

    public int MaxComboNameLength { get; set; } = 80;
    public int MaxScenarioTitleLength { get; set; } = 80;
    public int MaxCallerNameLength { get; set; } = 40;
    public int MaxStepTextLength { get; set; } = 300;
    public int MaxDialogueStepsPerScenario { get; set; } = 50;
    public long MaxMediaFileBytes { get; set; } = 10L * 1024 * 1024; // 10 MB
    public long MaxVideoFileBytes { get; set; } = 20L * 1024 * 1024; // 20 MB
    public long MaxSharePackageBytes { get; set; } = 25L * 1024 * 1024; // 25 MB
    public int MaxSharePackageCombos { get; set; } = 100;
    public int MaxUserCombos { get; set; } = 200;
    public int MaxUserScenarios { get; set; } = 100;
    public long MaxUserMediaQuotaBytes { get; set; } = 200L * 1024 * 1024; // 200 MB
    public string[] AllowedAudioExtensions { get; set; } = ["mp3", "m4a", "wav"];
    public string[] AllowedVideoExtensions { get; set; } = ["mp4"];
    public int[] AllowedCallDelaySeconds { get; set; } = [10, 30, 60, 300];
}

public class CorsOptions
{
    public const string SectionName = "Cors";
    public string[] AllowedOrigins { get; set; } = ["*"];
}

public class RateLimitingOptions
{
    public const string SectionName = "RateLimiting";
    public int AuthPermitLimit { get; set; } = 20;
    public int AuthWindowMinutes { get; set; } = 1;
    public int SharesPermitLimit { get; set; } = 60;
    public int SharesWindowMinutes { get; set; } = 1;
}

public class CleanupOptions
{
    public const string SectionName = "Cleanup";
    public int IntervalHours { get; set; } = 6;
    public int ExpiredShareRetentionDays { get; set; } = 7;
    public int OrphanedMediaGracePeriodHours { get; set; } = 24;
}

public class DatabaseOptions
{
    public const string SectionName = "Database";
    public bool AutoInitializeFromSql { get; set; } = true;
    public string SqlScriptPath { get; set; } = "../../trondb.sql";
}
