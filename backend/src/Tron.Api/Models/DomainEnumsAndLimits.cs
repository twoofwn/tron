using System.Diagnostics;

namespace Tron.Api.Models;

public enum UserRole { User, Admin }
public enum ScenarioCategory { Family, Work, Personal }
public enum ScenarioSource { BuiltIn, SampleUser, User }
public enum DialogueStepType { Speech, Wait }
public enum CallInterface { Phone, Zalo, Messenger }
public enum RingtoneType { InterfaceDefault, Classic, Custom }
public enum MediaKind { Voice, Ambient, Ringtone }
public enum ThemePreference { Dark, Light }

public static class DomainLimits
{
    public static int MaxComboNameLength { get; set; } = 80;
    public static int MaxScenarioTitleLength { get; set; } = 80;
    public static int MaxCallerNameLength { get; set; } = 40;
    public static int MaxStepTextLength { get; set; } = 300;
    public static int MaxDialogueStepsPerScenario { get; set; } = 50;
    public static long MaxMediaFileBytes { get; set; } = 10L * 1024 * 1024; // 10 MB
    public static long MaxSharePackageBytes { get; set; } = 25L * 1024 * 1024; // 25 MB
    public static int MaxSharePackageCombos { get; set; } = 100;
    public static int MaxUserCombos { get; set; } = 200;
    public static int MaxUserScenarios { get; set; } = 100;
    public static long MaxUserMediaQuotaBytes { get; set; } = 200L * 1024 * 1024; // 200 MB
    public static string[] AllowedAudioExtensions { get; set; } = ["mp3", "m4a", "wav"];
    public static int[] AllowedCallDelaySeconds { get; set; } = [10, 30, 60, 300];

    public static void Configure(DomainLimitOptions options)
    {
        if (options == null) return;
        MaxComboNameLength = options.MaxComboNameLength;
        MaxScenarioTitleLength = options.MaxScenarioTitleLength;
        MaxCallerNameLength = options.MaxCallerNameLength;
        MaxStepTextLength = options.MaxStepTextLength;
        MaxDialogueStepsPerScenario = options.MaxDialogueStepsPerScenario;
        MaxMediaFileBytes = options.MaxMediaFileBytes;
        MaxSharePackageBytes = options.MaxSharePackageBytes;
        MaxSharePackageCombos = options.MaxSharePackageCombos;
        MaxUserCombos = options.MaxUserCombos;
        MaxUserScenarios = options.MaxUserScenarios;
        MaxUserMediaQuotaBytes = options.MaxUserMediaQuotaBytes;
        if (options.AllowedAudioExtensions is { Length: > 0 })
        {
            AllowedAudioExtensions = options.AllowedAudioExtensions;
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
