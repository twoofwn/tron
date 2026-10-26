using Microsoft.EntityFrameworkCore;
using Tron.Api.Db;
using Tron.Api.Models;

namespace Tron.Api.Repositories;

public class UserRepository(TronDbContext db)
{
    public Task<bool> ExistsByNormalizedEmailAsync(string normalizedEmail, CancellationToken ct = default) =>
        db.Users.AnyAsync(u => u.NormalizedEmail == normalizedEmail, ct);

    public Task<User?> FindByNormalizedEmailAsync(string normalizedEmail, CancellationToken ct = default) =>
        db.Users.FirstOrDefaultAsync(u => u.NormalizedEmail == normalizedEmail, ct);

    public Task<User?> FindByIdAsync(Guid userId, bool onlyActive = true, CancellationToken ct = default) =>
        onlyActive
            ? db.Users.FirstOrDefaultAsync(u => u.Id == userId && u.IsActive, ct)
            : db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);

    public Task<RefreshToken?> FindRefreshTokenByHashAsync(string tokenHash, CancellationToken ct = default) =>
        db.RefreshTokens
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == tokenHash, ct);

    public Task<RefreshToken?> FindActiveRefreshTokenAsync(Guid userId, string tokenHash, CancellationToken ct = default) =>
        db.RefreshTokens
            .FirstOrDefaultAsync(t => t.UserId == userId && t.TokenHash == tokenHash && t.RevokedAt == null, ct);

    public Task<List<RefreshToken>> GetActiveRefreshTokensAsync(Guid userId, CancellationToken ct = default) =>
        db.RefreshTokens
            .Where(t => t.UserId == userId && t.RevokedAt == null)
            .ToListAsync(ct);

    public void AddUser(User user) => db.Users.Add(user);

    public void AddRefreshToken(RefreshToken token) => db.RefreshTokens.Add(token);

    public Task<Backup?> GetLatestBackupAsync(Guid userId, CancellationToken ct = default) =>
        db.Backups
            .AsNoTracking()
            .Where(b => b.UserId == userId)
            .OrderByDescending(b => b.CreatedAt)
            .FirstOrDefaultAsync(ct);

    public Task<int> CountUserCombosAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos.CountAsync(c => c.OwnerId == userId, ct);

    public Task<int> CountUserScenariosAsync(Guid userId, CancellationToken ct = default) =>
        db.Scenarios.CountAsync(s => s.OwnerId == userId, ct);

    public async Task<long> GetUserActiveMediaBytesAsync(Guid userId, CancellationToken ct = default) =>
        await db.MediaFiles
            .Where(m => m.OwnerId == userId && m.OrphanedAt == null)
            .SumAsync(m => (long?)m.SizeBytes, ct) ?? 0L;

    public async Task<List<MediaFile>> DeleteUserAndCascadeDependentsAsync(User user, CancellationToken ct = default)
    {
        var userId = user.Id;
        var mediaFiles = await db.MediaFiles.Where(m => m.OwnerId == userId).ToListAsync(ct);

        var userScenarioIds = await db.Scenarios
            .Where(s => s.OwnerId == userId)
            .Select(s => s.Id)
            .ToListAsync(ct);

        if (userScenarioIds.Count > 0)
        {
            var steps = await db.DialogueSteps
                .Where(st => userScenarioIds.Contains(st.ScenarioId))
                .ToListAsync(ct);
            db.DialogueSteps.RemoveRange(steps);
        }

        var userShareIds = await db.SharePackages
            .Where(s => s.CreatedById == userId)
            .Select(s => s.Id)
            .ToListAsync(ct);

        if (userShareIds.Count > 0)
        {
            var shareMedias = await db.SharePackageMedia
                .Where(sm => userShareIds.Contains(sm.SharePackageId))
                .ToListAsync(ct);
            db.SharePackageMedia.RemoveRange(shareMedias);
        }

        var combos = await db.Combos.Where(c => c.OwnerId == userId).ToListAsync(ct);
        db.Combos.RemoveRange(combos);

        var ambients = await db.AmbientSounds.Where(a => a.OwnerId == userId).ToListAsync(ct);
        db.AmbientSounds.RemoveRange(ambients);

        var marketPurchases = await db.MarketPurchases.Where(p => p.BuyerId == userId).ToListAsync(ct);
        db.MarketPurchases.RemoveRange(marketPurchases);

        db.Users.Remove(user);
        await db.SaveChangesAsync(ct);

        return mediaFiles;
    }

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
