using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Tron.Api.Db;
using Tron.Api.Models;

namespace Tron.Api.Services;

public class StorageCleanupWorker(
    IServiceProvider serviceProvider,
    IMediaStorage mediaStorage,
    IOptions<CleanupOptions> options,
    ILogger<StorageCleanupWorker> logger) : BackgroundService
{
    private TimeSpan Interval => TimeSpan.FromHours(Math.Max(1, options.Value.IntervalHours));

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(Interval, stoppingToken);
                await CleanupOnceAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error during storage cleanup worker execution");
            }
        }
    }

    public async Task<int> CleanupOnceAsync(CancellationToken ct = default)
    {
        using var scope = serviceProvider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<TronDbContext>();
        var now = DateTime.UtcNow;

        // 1. Delete expired share packages older than retention days past expiry
        var retentionDays = Math.Max(1, options.Value.ExpiredShareRetentionDays);
        var expiredShares = await db.SharePackages
            .Where(s => s.ExpiresAt < now.AddDays(-retentionDays))
            .ToListAsync(ct);

        if (expiredShares.Count > 0)
        {
            db.SharePackages.RemoveRange(expiredShares);
            await db.SaveChangesAsync(ct);
        }

        // 2. Delete orphaned media files older than grace period not referenced by any active share
        var graceHours = Math.Max(1, options.Value.OrphanedMediaGracePeriodHours);
        var cutoff = now.AddHours(-graceHours);
        var orphanedMedia = await db.MediaFiles
            .Where(m => m.OrphanedAt != null && m.OrphanedAt < cutoff)
            .ToListAsync(ct);

        var removedCount = 0;
        foreach (var media in orphanedMedia)
        {
            var usedInShare = await db.SharePackageMedia
                .AnyAsync(sm => sm.MediaFileId == media.Id, ct);

            if (usedInShare)
            {
                continue;
            }

            await mediaStorage.DeleteAsync(media.StorageKey, ct);
            db.MediaFiles.Remove(media);
            removedCount++;
        }

        if (removedCount > 0)
        {
            await db.SaveChangesAsync(ct);
        }

        return removedCount;
    }
}
