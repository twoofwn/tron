using Microsoft.EntityFrameworkCore;
using Tron.Api.Db;
using Tron.Api.Models;

namespace Tron.Api.Repositories;

public class UserDataRepository(TronDbContext db)
{
    public Task<List<Combo>> GetUserCombosAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos
            .AsNoTracking()
            .Include(c => c.Backgrounds.OrderBy(b => b.Order))
            .Where(c => c.OwnerId == userId)
            .OrderBy(c => c.SortOrder)
            .ThenBy(c => c.CreatedAt)
            .ToListAsync(ct);

    public Task<Combo?> FindUserComboWithBackgroundsAsync(Guid userId, Guid comboId, CancellationToken ct = default) =>
        db.Combos
            .Include(c => c.Backgrounds)
            .FirstOrDefaultAsync(c => c.OwnerId == userId && c.Id == comboId, ct);

    public Task<int> CountUserCombosAsync(Guid userId, CancellationToken ct = default) =>
        db.Combos.CountAsync(c => c.OwnerId == userId, ct);

    public void AddCombo(Combo combo) => db.Combos.Add(combo);

    public void RemoveComboBackgrounds(IEnumerable<ComboBackground> backgrounds) =>
        db.ComboBackgrounds.RemoveRange(backgrounds);

    public void RemoveCombo(Combo combo) => db.Combos.Remove(combo);

    public Task<List<Scenario>> GetUserScenariosAsync(Guid userId, CancellationToken ct = default) =>
        db.Scenarios
            .AsNoTracking()
            .Include(s => s.Steps.OrderBy(st => st.Order))
            .Where(s => s.OwnerId == userId)
            .OrderBy(s => s.CreatedAt)
            .ToListAsync(ct);

    public Task<Scenario?> FindUserScenarioWithStepsAsync(Guid userId, string scopedId, CancellationToken ct = default) =>
        db.Scenarios
            .Include(s => s.Steps)
            .FirstOrDefaultAsync(s => s.OwnerId == userId && s.Id == scopedId, ct);

    public Task<int> CountUserScenariosAsync(Guid userId, CancellationToken ct = default) =>
        db.Scenarios.CountAsync(s => s.OwnerId == userId, ct);

    public void AddScenario(Scenario scenario) => db.Scenarios.Add(scenario);

    public void RemoveDialogueSteps(IEnumerable<DialogueStep> steps) =>
        db.DialogueSteps.RemoveRange(steps);

    public void RemoveScenario(Scenario scenario) => db.Scenarios.Remove(scenario);

    public Task<List<AmbientSound>> GetUserAmbientSoundsAsync(Guid userId, CancellationToken ct = default) =>
        db.AmbientSounds
            .AsNoTracking()
            .Where(a => a.OwnerId == userId)
            .OrderBy(a => a.SortOrder)
            .ThenBy(a => a.CreatedAt)
            .ToListAsync(ct);

    public Task<AmbientSound?> FindUserAmbientSoundAsync(Guid userId, string scopedId, CancellationToken ct = default) =>
        db.AmbientSounds.FirstOrDefaultAsync(a => a.OwnerId == userId && a.Id == scopedId, ct);

    public void AddAmbientSound(AmbientSound sound) => db.AmbientSounds.Add(sound);

    public void RemoveAmbientSound(AmbientSound sound) => db.AmbientSounds.Remove(sound);

    public Task<UserSettings?> GetUserSettingsAsync(Guid userId, CancellationToken ct = default) =>
        db.UserSettings.FirstOrDefaultAsync(s => s.UserId == userId, ct);

    public void AddUserSettings(UserSettings settings) => db.UserSettings.Add(settings);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}

public class MarketRepository(TronDbContext db)
{
    public Task<List<MarketPackage>> GetPublishedPackagesAsync(CancellationToken ct = default) =>
        db.MarketPackages
            .AsNoTracking()
            .Where(m => m.IsPublished)
            .OrderByDescending(m => m.IsOfficial)
            .ThenByDescending(m => m.DownloadCount)
            .ThenByDescending(m => m.CreatedAt)
            .ToListAsync(ct);

    public Task<MarketPackage?> FindByIdAsync(Guid id, bool asNoTracking = false, CancellationToken ct = default) =>
        asNoTracking
            ? db.MarketPackages.AsNoTracking().FirstOrDefaultAsync(m => m.Id == id, ct)
            : db.MarketPackages.FirstOrDefaultAsync(m => m.Id == id, ct);

    public Task<bool> ExistsByCodeAsync(string code, CancellationToken ct = default) =>
        db.MarketPackages.AnyAsync(m => m.Code == code, ct);

    public Task<List<Guid>> GetPurchasedPackageIdsAsync(Guid buyerId, CancellationToken ct = default) =>
        db.MarketPurchases
            .AsNoTracking()
            .Where(p => p.BuyerId == buyerId)
            .Select(p => p.MarketPackageId)
            .ToListAsync(ct);

    public Task<MarketPurchase?> FindPurchaseAsync(Guid packageId, Guid buyerId, CancellationToken ct = default) =>
        db.MarketPurchases.FirstOrDefaultAsync(p => p.MarketPackageId == packageId && p.BuyerId == buyerId, ct);

    public void AddPackage(MarketPackage package) => db.MarketPackages.Add(package);

    public void RemovePackage(MarketPackage package) => db.MarketPackages.Remove(package);

    public void AddPurchase(MarketPurchase purchase) => db.MarketPurchases.Add(purchase);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
