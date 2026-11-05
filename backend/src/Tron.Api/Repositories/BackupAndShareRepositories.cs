using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Tron.Api.Db;
using Tron.Api.Models;

namespace Tron.Api.Repositories;

public class BackupRepository(TronDbContext db)
{
    public Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken ct = default) =>
        db.Database.BeginTransactionAsync(ct);

    public Task<Backup?> GetLatestBackupAsync(Guid userId, CancellationToken ct = default) =>
        db.Backups
            .AsNoTracking()
            .Where(b => b.UserId == userId)
            .OrderByDescending(b => b.CreatedAt)
            .FirstOrDefaultAsync(ct);

    public Task<int> CountCombosAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos.CountAsync(c => c.OwnerId == userId, ct);

    public Task<int> CountScenariosAsync(Guid userId, CancellationToken ct = default) =>
        db.Scenarios.CountAsync(s => s.OwnerId == userId, ct);

    public Task<int> CountAmbientsAsync(Guid userId, CancellationToken ct = default) =>
        db.AmbientSounds.CountAsync(a => a.OwnerId == userId, ct);

    public async Task<(int Count, long Bytes)> GetActiveMediaStatsAsync(Guid userId, CancellationToken ct = default)
    {
        var stats = await db.MediaFiles
            .Where(m => m.OwnerId == userId && m.OrphanedAt == null)
            .GroupBy(_ => 1)
            .Select(g => new { Count = g.Count(), Bytes = g.Sum(x => x.SizeBytes) })
            .FirstOrDefaultAsync(ct);
        return (stats?.Count ?? 0, stats?.Bytes ?? 0L);
    }

    public Task<UserSettings?> GetUserSettingsAsync(Guid userId, bool asNoTracking = false, CancellationToken ct = default) =>
        asNoTracking
            ? db.UserSettings.AsNoTracking().FirstOrDefaultAsync(s => s.UserId == userId, ct)
            : db.UserSettings.FirstOrDefaultAsync(s => s.UserId == userId, ct);

    public void AddUserSettings(UserSettings settings) => db.UserSettings.Add(settings);

    public Task<Dictionary<Guid, Guid?>> GetComboVoiceIdsAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos.Where(c => c.OwnerId == userId).ToDictionaryAsync(c => c.Id, c => c.VoiceMediaId, ct);

    public Task<Dictionary<Guid, Guid?>> GetComboAvatarIdsAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos.Where(c => c.OwnerId == userId).ToDictionaryAsync(c => c.Id, c => c.AvatarMediaId, ct);

    public Task<Dictionary<Guid, (CallType CallType, Guid? VideoMediaId, string? CallerName, VideoEndAction VideoEndAction)>> GetComboVideosAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos.Where(c => c.OwnerId == userId)
            .Select(c => new { c.Id, c.CallType, c.VideoMediaId, c.CallerName, c.VideoEndAction })
            .ToDictionaryAsync(c => c.Id, c => (c.CallType, c.VideoMediaId, c.CallerName, c.VideoEndAction), ct);

    public async Task ClearUserSnapshotEntitiesAsync(Guid userId, CancellationToken ct = default)
    {
        var oldCombos = await db.Combos.Where(c => c.OwnerId == userId).ToListAsync(ct);
        db.Combos.RemoveRange(oldCombos);

        var oldScenarioIds = await db.Scenarios.Where(s => s.OwnerId == userId).Select(s => s.Id).ToListAsync(ct);
        if (oldScenarioIds.Count > 0)
        {
            var oldSteps = await db.DialogueSteps.Where(st => oldScenarioIds.Contains(st.ScenarioId)).ToListAsync(ct);
            db.DialogueSteps.RemoveRange(oldSteps);
            var oldScenarios = await db.Scenarios.Where(s => s.OwnerId == userId).ToListAsync(ct);
            db.Scenarios.RemoveRange(oldScenarios);
        }

        var oldAmbients = await db.AmbientSounds.Where(a => a.OwnerId == userId).ToListAsync(ct);
        db.AmbientSounds.RemoveRange(oldAmbients);
        await db.SaveChangesAsync(ct);
    }

    public void AddAmbientSound(AmbientSound sound) => db.AmbientSounds.Add(sound);
    public void AddScenario(Scenario scenario) => db.Scenarios.Add(scenario);
    public void AddCombo(Combo combo) => db.Combos.Add(combo);
    public void AddBackup(Backup backup) => db.Backups.Add(backup);

    public Task<List<Guid>> GetActiveSharedMediaIdsAsync(Guid userId, CancellationToken ct = default) =>
        db.SharePackageMedia
            .Where(sm => sm.SharePackage!.CreatedById == userId && sm.SharePackage.RevokedAt == null && sm.SharePackage.ExpiresAt > DateTime.UtcNow)
            .Select(sm => sm.MediaFileId)
            .Distinct()
            .ToListAsync(ct);

    public Task<List<MediaFile>> GetUserMediaFilesAsync(Guid userId, bool onlyActive = false, CancellationToken ct = default) =>
        onlyActive
            ? db.MediaFiles.AsNoTracking().Where(m => m.OwnerId == userId && m.OrphanedAt == null).ToListAsync(ct)
            : db.MediaFiles.Where(m => m.OwnerId == userId).ToListAsync(ct);

    public Task<List<AmbientSound>> GetUserAmbientSoundsAsync(Guid userId, CancellationToken ct = default) =>
        db.AmbientSounds
            .AsNoTracking()
            .Where(a => a.OwnerId == userId)
            .OrderBy(a => a.SortOrder)
            .ToListAsync(ct);

    public Task<List<Scenario>> GetUserScenariosWithStepsAsync(Guid userId, CancellationToken ct = default) =>
        db.Scenarios
            .AsNoTracking()
            .Include(s => s.Steps.OrderBy(st => st.Order))
            .Where(s => s.OwnerId == userId)
            .OrderBy(s => s.CreatedAt)
            .ToListAsync(ct);

    public Task<List<Combo>> GetUserCombosWithBackgroundsAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos
            .AsNoTracking()
            .Include(c => c.Backgrounds.OrderBy(b => b.Order))
            .Where(c => c.OwnerId == userId)
            .OrderBy(c => c.SortOrder)
            .ToListAsync(ct);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}

public class ShareRepository(TronDbContext db)
{
    public Task<bool> ExistsByCodeAsync(string code, CancellationToken ct = default) =>
        db.SharePackages.AnyAsync(s => s.Code == code, ct);

    public Task<SharePackage?> FindByCodeWithMediaAsync(string code, bool asNoTracking = false, CancellationToken ct = default)
    {
        var query = asNoTracking ? db.SharePackages.AsNoTracking() : db.SharePackages;
        return query
            .Include(s => s.MediaItems)
            .ThenInclude(sm => sm.MediaFile)
            .FirstOrDefaultAsync(s => s.Code == code, ct);
    }

    public Task<SharePackage?> FindUserShareByCodeAsync(Guid userId, string code, CancellationToken ct = default) =>
        db.SharePackages.FirstOrDefaultAsync(s => s.Code == code && s.CreatedById == userId, ct);

    public Task<List<SharePackage>> GetUserSharesWithMediaAsync(Guid userId, CancellationToken ct = default) =>
        db.SharePackages
            .AsNoTracking()
            .Include(s => s.MediaItems)
            .ThenInclude(sm => sm.MediaFile)
            .Where(s => s.CreatedById == userId)
            .OrderByDescending(s => s.CreatedAt)
            .Take(50)
            .ToListAsync(ct);

    public void Add(SharePackage share) => db.SharePackages.Add(share);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
