using Microsoft.EntityFrameworkCore;
using Tron.Api.Db;
using Tron.Api.Models;

namespace Tron.Api.Repositories;

public class CatalogRepository(TronDbContext db)
{
    public Task<List<Scenario>> GetBuiltInScenariosAsync(CancellationToken ct = default) =>
        db.Scenarios
            .AsNoTracking()
            .Include(s => s.Steps.OrderBy(st => st.Order))
            .Where(s => s.OwnerId == null)
            .OrderBy(s => s.Id)
            .ToListAsync(ct);

    public Task<ScenarioAlias?> FindAliasAsync(string legacyId, CancellationToken ct = default) =>
        db.ScenarioAliases
            .AsNoTracking()
            .FirstOrDefaultAsync(a => a.LegacyId == legacyId, ct);

    public Task<Scenario?> FindBuiltInScenarioByIdAsync(string id, CancellationToken ct = default) =>
        db.Scenarios
            .AsNoTracking()
            .Include(s => s.Steps.OrderBy(st => st.Order))
            .FirstOrDefaultAsync(s => s.OwnerId == null && s.Id == id, ct);

    public Task<List<AmbientSound>> GetBuiltInAmbientSoundsAsync(CancellationToken ct = default) =>
        db.AmbientSounds
            .AsNoTracking()
            .Where(a => a.OwnerId == null)
            .OrderBy(a => a.SortOrder)
            .ToListAsync(ct);

    public Task<List<Ringtone>> GetRingtonesAsync(CancellationToken ct = default) =>
        db.Ringtones
            .AsNoTracking()
            .OrderBy(r => r.SortOrder)
            .ToListAsync(ct);
}

public class MediaRepository(TronDbContext db)
{
    public Task<List<MediaFile>> GetUserMediaByHashesAsync(Guid userId, IReadOnlyCollection<string> hashes, CancellationToken ct = default) =>
        db.MediaFiles
            .AsNoTracking()
            .Where(m => m.OwnerId == userId && hashes.Contains(m.Sha256))
            .ToListAsync(ct);

    public Task<MediaFile?> FindUserMediaByHashAsync(Guid userId, string sha256Hex, CancellationToken ct = default) =>
        db.MediaFiles
            .FirstOrDefaultAsync(m => m.OwnerId == userId && m.Sha256 == sha256Hex, ct);

    public async Task<long> GetUserActiveUsageBytesAsync(Guid userId, CancellationToken ct = default) =>
        await db.MediaFiles
            .Where(m => m.OwnerId == userId && m.OrphanedAt == null)
            .SumAsync(m => (long?)m.SizeBytes, ct) ?? 0L;

    public Task<MediaFile?> FindAccessibleMediaByIdAsync(Guid userId, Guid mediaId, CancellationToken ct = default) =>
        db.MediaFiles
            .AsNoTracking()
            .FirstOrDefaultAsync(m => m.Id == mediaId && (m.OwnerId == userId || m.OwnerId == null), ct);

    public Task<List<Guid>> GetOwnedMediaIdsAsync(Guid userId, IReadOnlyCollection<Guid> mediaIds, CancellationToken ct = default) =>
        db.MediaFiles
            .Where(m => m.OwnerId == userId && mediaIds.Contains(m.Id))
            .Select(m => m.Id)
            .ToListAsync(ct);

    public Task<List<MediaFile>> GetOwnedMediasByIdsAsync(Guid userId, IReadOnlyCollection<Guid> mediaIds, CancellationToken ct = default) =>
        db.MediaFiles
            .AsNoTracking()
            .Where(m => m.OwnerId == userId && mediaIds.Contains(m.Id))
            .ToListAsync(ct);

    public void Add(MediaFile media) => db.MediaFiles.Add(media);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
