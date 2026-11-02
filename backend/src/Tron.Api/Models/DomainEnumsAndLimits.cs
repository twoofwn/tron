using System.Diagnostics;

namespace Tron.Api.Models;

public enum UserRole { User, Admin }
public enum ScenarioCategory { Family, Work, Personal }
public enum ScenarioSource { BuiltIn, SampleUser, User }
public enum DialogueStepType { Speech, Wait }
public enum CallInterface { Phone, Zalo, Messenger }
public enum CallType { Voice, Video }
public enum VideoEndAction { HangUp, Loop }
public enum RingtoneType { InterfaceDefault, Classic, Custom }
public enum MediaKind { Voice, Ambient, Ringtone, Video }
public enum ThemePreference { Dark, Light }

public static class DomainLimits
{
    public static int MaxComboNameLength { get; set; } = 80;
    public static int MaxScenarioTitleLength { get; set; } = 80;
    public static int MaxCallerNameLength { get; set; } = 40;
    public static int MaxStepTextLength { get; set; } = 300;
    public static int MaxDialogueStepsPerScenario { get; set; } = 50;
    public static long MaxMediaFileBytes { get; set; } = 10L * 1024 * 1024; // 10 MB
    public static long MaxVideoFileBytes { get; set; } = 20L * 1024 * 1024; // 20 MB
    public static long MaxSharePackageBytes { get; set; } = 25L * 1024 * 1024; // 25 MB
    public static int MaxSharePackageCombos { get; set; } = 100;
    public static int MaxUserCombos { get; set; } = 200;
    public static int MaxUserScenarios { get; set; } = 100;
    public static long MaxUserMediaQuotaBytes { get; set; } = 200L * 1024 * 1024; // 200 MB
    public static string[] AllowedAudioExtensions { get; set; } = ["mp3", "m4a", "wav"];
    public static string[] AllowedVideoExtensions { get; set; } = ["mp4"];
    public static int[] AllowedCallDelaySeconds { get; set; } = [10, 30, 60, 300];

    public static bool IsVideoExtension(string extension) =>
        AllowedVideoExtensions.Contains(extension.TrimStart('.').ToLowerInvariant());

    /// <summary>Giới hạn dung lượng theo loại file: video cuộc gọi được phép lớn hơn âm thanh.</summary>
    public static long MaxBytesForExtension(string extension) =>
        IsVideoExtension(extension) ? MaxVideoFileBytes : MaxMediaFileBytes;

    /// <summary>Giới hạn lớn nhất của mọi loại file, dùng khi chưa biết định dạng.</summary>
    public static long MaxAnyMediaFileBytes => Math.Max(MaxMediaFileBytes, MaxVideoFileBytes);

    public static void Configure(DomainLimitOptions options)
    {
        if (options == null) return;
        MaxComboNameLength = options.MaxComboNameLength;
        MaxScenarioTitleLength = options.MaxScenarioTitleLength;
        MaxCallerNameLength = options.MaxCallerNameLength;
        MaxStepTextLength = options.MaxStepTextLength;
        MaxDialogueStepsPerScenario = options.MaxDialogueStepsPerScenario;
        MaxMediaFileBytes = options.MaxMediaFileBytes;
        MaxVideoFileBytes = options.MaxVideoFileBytes;
        MaxSharePackageBytes = options.MaxSharePackageBytes;
        MaxSharePackageCombos = options.MaxSharePackageCombos;
        MaxUserCombos = options.MaxUserCombos;
        MaxUserScenarios = options.MaxUserScenarios;
        MaxUserMediaQuotaBytes = options.MaxUserMediaQuotaBytes;
        if (options.AllowedAudioExtensions is { Length: > 0 })
        {
            AllowedAudioExtensions = options.AllowedAudioExtensions;
        }
        if (options.AllowedVideoExtensions is { Length: > 0 })
        {
            AllowedVideoExtensions = options.AllowedVideoExtensions;
        }
        if (options.AllowedCallDelaySeconds is { Length: > 0 })
        {
            AllowedCallDelaySeconds = options.AllowedCallDelaySeconds;
        }
    }
}

[DebuggerNonUserCode]
public class ApiDomainException(string errorCode, string message, int statusCode = 400)
    : Exception(message)
{
    public string ErrorCode { get; } = errorCode;
    public int StatusCode { get; } = statusCode;
}
