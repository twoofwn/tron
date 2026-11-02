using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Tron.Api.Db;
using Tron.Api.Models;
using Tron.Api.Services;

namespace Tron.Api.Controllers;

public static class ClaimsPrincipalExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal user)
    {
        var raw = user.FindFirstValue(ClaimTypes.NameIdentifier) ?? user.FindFirstValue("sub");
        if (Guid.TryParse(raw, out var id))
        {
            return id;
        }
        throw new ApiDomainException("UNAUTHORIZED", "Phiên đăng nhập không hợp lệ.", 401);
    }
}

[ApiController]
[Route("api/v1/auth")]
public class AuthController(AuthService authService) : ControllerBase
{
    [HttpPost("register")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult> Register([FromBody] RegisterRequest request, CancellationToken ct) =>
        this.ToActionResult(await authService.RegisterAsync(request, ct));

    [HttpPost("login")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult> Login([FromBody] LoginRequest request, CancellationToken ct) =>
        this.ToActionResult(await authService.LoginAsync(request, ct));

    [HttpPost("refresh")]
    [EnableRateLimiting("auth")]
    public async Task<ActionResult> Refresh([FromBody] RefreshRequest request, CancellationToken ct) =>
        this.ToActionResult(await authService.RefreshAsync(request, ct));

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest? request, CancellationToken ct)
    {
        await authService.LogoutAsync(User.GetUserId(), request?.RefreshToken, ct);
        return NoContent();
    }
}

[ApiController]
[Authorize]
[Route("api/v1/me")]
public class MeController(AuthService authService, UserDataService userDataService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<UserProfileDto>> GetProfile(CancellationToken ct) =>
        Ok(await authService.GetProfileAsync(User.GetUserId(), ct));

    [HttpPut]
    public async Task<ActionResult> UpdateProfile([FromBody] UpdateProfileRequest request, CancellationToken ct) =>
        this.ToActionResult(await authService.UpdateProfileAsync(User.GetUserId(), request, ct));

    [HttpPut("settings")]
    public async Task<ActionResult<UserSettingsDto>> UpdateSettings([FromBody] UserSettingsDto request, CancellationToken ct) =>
        Ok(await userDataService.UpdateUserSettingsAsync(User.GetUserId(), request, ct));

    [HttpPut("password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request, CancellationToken ct) =>
        this.ToActionResult(await authService.ChangePasswordAsync(User.GetUserId(), request, ct));

    [HttpDelete]
    public async Task<IActionResult> DeleteAccount(CancellationToken ct)
    {
        await authService.DeleteAccountAsync(User.GetUserId(), ct);
        return NoContent();
    }
}

[ApiController]
[Authorize]
[Route("api/v1/catalog")]
public class CatalogController(CatalogAndMediaService catalogService) : ControllerBase
{
    [HttpGet("scenarios")]
    public async Task<ActionResult<IReadOnlyList<ScenarioDto>>> GetScenarios(CancellationToken ct) =>
        Ok(await catalogService.GetCatalogScenariosAsync(ct));

    [HttpGet("scenarios/{id}")]
    public async Task<ActionResult<ScenarioDto>> GetScenarioById(string id, CancellationToken ct) =>
        Ok(await catalogService.GetCatalogScenarioByIdAsync(id, ct));

    [HttpGet("ambient-sounds")]
    public async Task<ActionResult<IReadOnlyList<AmbientSoundDto>>> GetAmbientSounds(CancellationToken ct) =>
        Ok(await catalogService.GetCatalogAmbientSoundsAsync(ct));

    [HttpGet("ringtones")]
    public async Task<ActionResult<IReadOnlyList<RingtoneDto>>> GetRingtones(CancellationToken ct) =>
        Ok(await catalogService.GetCatalogRingtonesAsync(ct));
}

[ApiController]
[Authorize]
[Route("api/v1/media")]
public class MediaController(CatalogAndMediaService mediaService) : ControllerBase
{
    [HttpPost("check")]
    public async Task<ActionResult<MediaCheckResponse>> CheckMedia([FromBody] MediaCheckRequest request, CancellationToken ct) =>
        Ok(await mediaService.CheckMediaAsync(User.GetUserId(), request, ct));

    [HttpPost]
    // Đủ cho video cuộc gọi 20 MB cộng phần đầu multipart; giới hạn theo loại file kiểm tra trong service.
    [RequestSizeLimit(22 * 1024 * 1024)]
    public async Task<ActionResult<MediaUploadResponse>> UploadMedia(
        IFormFile file,
        [FromForm] string? kind,
        CancellationToken ct)
    {
        if (file is null || file.Length == 0)
        {
            throw new ApiDomainException("MEDIA_EMPTY_OR_CORRUPT", "Chưa chọn file âm thanh hoặc video.");
        }

        var mediaKind = Enum.TryParse<MediaKind>(kind, true, out var parsed) ? parsed : MediaKind.Voice;
        await using var stream = file.OpenReadStream();
        var result = await mediaService.UploadMediaAsync(
            User.GetUserId(),
            file.FileName,
            mediaKind,
            stream,
            file.Length,
            ct);

        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> DownloadMedia(Guid id, CancellationToken ct)
    {
        var (meta, stream) = await mediaService.OpenUserMediaAsync(User.GetUserId(), id, ct);
        return File(stream, meta.ContentType, enableRangeProcessing: true);
    }
}

[ApiController]
[Authorize]
[Route("api/v1/backup")]
public class BackupController(BackupAndShareService backupService) : ControllerBase
{
    [HttpGet("status")]
    public async Task<ActionResult<BackupStatusDto>> GetStatus(CancellationToken ct) =>
        Ok(await backupService.GetBackupStatusAsync(User.GetUserId(), ct));

    [HttpPut]
    public async Task<ActionResult<BackupStatusDto>> SaveBackup([FromBody] BackupSnapshotRequest request, CancellationToken ct) =>
        Ok(await backupService.SaveBackupSnapshotAsync(User.GetUserId(), request, ct));

    [HttpGet]
    public async Task<ActionResult<BackupRestoreResponse>> RestoreBackup(CancellationToken ct) =>
        Ok(await backupService.GetBackupRestoreAsync(User.GetUserId(), ct));
}

[ApiController]
[Authorize]
[Route("api/v1/shares")]
public class SharesController(BackupAndShareService shareService) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult> CreateShare([FromBody] CreateShareRequest request, CancellationToken ct) =>
        this.ToActionResult(await shareService.CreateShareAsync(User.GetUserId(), request, ct));

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<ShareSummaryDto>>> GetMyShares(CancellationToken ct) =>
        Ok(await shareService.GetMySharesAsync(User.GetUserId(), ct));

    [HttpGet("{code}")]
    [EnableRateLimiting("shares")]
    public async Task<ActionResult> GetShareByCode(string code, CancellationToken ct) =>
        this.ToActionResult(await shareService.GetShareByCodeAsync(code, ct));

    [HttpPost("{code}/import")]
    [EnableRateLimiting("shares")]
    public async Task<ActionResult> ImportShare(string code, CancellationToken ct) =>
        this.ToActionResult(await shareService.RecordImportAsync(code, ct));

    [HttpGet("{code}/media/{mediaId:guid}")]
    [EnableRateLimiting("shares")]
    public async Task<IActionResult> DownloadShareMedia(string code, Guid mediaId, CancellationToken ct)
    {
        var (meta, stream) = await shareService.OpenShareMediaAsync(code, mediaId, ct);
        return File(stream, meta.ContentType, enableRangeProcessing: true);
    }

    [HttpDelete("{code}")]
    public async Task<IActionResult> RevokeShare(string code, CancellationToken ct)
    {
        await shareService.RevokeShareAsync(User.GetUserId(), code, ct);
        return NoContent();
    }
}

[ApiController]
[Authorize]
[Route("api/v1/combos")]
public class CombosController(UserDataService userDataService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<BackupComboDto>>> GetCombos(CancellationToken ct) =>
        Ok(await userDataService.GetCombosAsync(User.GetUserId(), ct));

    [HttpPost]
    public async Task<ActionResult<BackupComboDto>> UpsertCombo([FromBody] BackupComboDto request, CancellationToken ct) =>
        Ok(await userDataService.UpsertComboAsync(User.GetUserId(), request, ct));

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<BackupComboDto>> UpdateCombo(Guid id, [FromBody] BackupComboDto request, CancellationToken ct) =>
        Ok(await userDataService.UpsertComboAsync(User.GetUserId(), request with { Id = id }, ct));

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteCombo(Guid id, CancellationToken ct)
    {
        await userDataService.DeleteComboAsync(User.GetUserId(), id, ct);
        return NoContent();
    }
}

[ApiController]
[Authorize]
[Route("api/v1/scenarios")]
public class UserScenariosController(UserDataService userDataService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<UserScenariosBundleDto>> GetUserScenariosBundle(CancellationToken ct) =>
        Ok(await userDataService.GetUserScenariosBundleAsync(User.GetUserId(), ct));

    [HttpPost]
    public async Task<ActionResult<ScenarioDto>> UpsertScenario([FromBody] ScenarioDto request, CancellationToken ct) =>
        Ok(await userDataService.UpsertUserScenarioAsync(User.GetUserId(), request, ct));

    [HttpPut("{id}")]
    public async Task<ActionResult<ScenarioDto>> UpdateScenario(string id, [FromBody] ScenarioDto request, CancellationToken ct) =>
        Ok(await userDataService.UpsertUserScenarioAsync(User.GetUserId(), request with { Id = id }, ct));

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteScenario(string id, CancellationToken ct)
    {
        await userDataService.DeleteUserScenarioAsync(User.GetUserId(), id, ct);
        return NoContent();
    }

    [HttpPost("ambient-sounds")]
    public async Task<ActionResult<AmbientSoundDto>> UpsertAmbientSound([FromBody] AmbientSoundDto request, CancellationToken ct) =>
        Ok(await userDataService.UpsertUserAmbientSoundAsync(User.GetUserId(), request, ct));

    [HttpDelete("ambient-sounds/{id}")]
    public async Task<IActionResult> DeleteAmbientSound(string id, CancellationToken ct)
    {
        await userDataService.DeleteUserAmbientSoundAsync(User.GetUserId(), id, ct);
        return NoContent();
    }
}

[ApiController]
[Authorize]
[Route("api/v1/market")]
public class MarketController(MarketService marketService) : ControllerBase
{
    [HttpGet("packages")]
    public async Task<ActionResult<IReadOnlyList<MarketPackageDto>>> GetPackages(
        [FromQuery] string? filter,
        [FromQuery] string? search,
        CancellationToken ct) =>
        Ok(await marketService.GetPackagesAsync(User.GetUserId(), filter, search, ct));

    [HttpGet("packages/{id:guid}")]
    public async Task<ActionResult<MarketPackageDto>> GetPackageById(Guid id, CancellationToken ct) =>
        Ok(await marketService.GetPackageByIdAsync(User.GetUserId(), id, ct));

    [HttpPost("packages")]
    public async Task<ActionResult> PublishPackage([FromBody] CreateMarketPackageRequest request, CancellationToken ct) =>
        this.ToActionResult(await marketService.PublishPackageAsync(User.GetUserId(), request, ct));

    [HttpPost("packages/{id:guid}/buy")]
    public async Task<ActionResult> PurchasePackage(Guid id, CancellationToken ct) =>
        this.ToActionResult(await marketService.PurchaseOrClaimPackageAsync(User.GetUserId(), id, ct));

    [HttpDelete("packages/{id:guid}")]
    public async Task<IActionResult> DeletePackage(Guid id, CancellationToken ct) =>
        this.ToActionResult(await marketService.DeletePackageAsync(User.GetUserId(), id, ct));
}

[ApiController]
[Route("api/v1/health")]
public class HealthController(TronDbContext db, IMediaStorage storage) : ControllerBase
{
    [HttpGet]
    public IActionResult GetLiveness() => Ok(new { status = "Healthy", timestamp = DateTime.UtcNow });

    [HttpGet("ready")]
    public async Task<IActionResult> GetReadiness(CancellationToken ct)
    {
        var dbOk = await db.Database.CanConnectAsync(ct);
        var diskOk = storage.IsWritable();
        if (!dbOk || !diskOk)
        {
            return StatusCode(503, new { status = "Degraded", database = dbOk, storage = diskOk });
        }
        return Ok(new { status = "Ready", database = dbOk, storage = diskOk, timestamp = DateTime.UtcNow });
    }
}
