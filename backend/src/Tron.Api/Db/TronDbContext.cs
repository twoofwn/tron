using Microsoft.EntityFrameworkCore;
using Tron.Api.Models;

namespace Tron.Api.Db;

public class TronDbContext(DbContextOptions<TronDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<UserSettings> UserSettings => Set<UserSettings>();
    public DbSet<MediaFile> MediaFiles => Set<MediaFile>();
    public DbSet<Scenario> Scenarios => Set<Scenario>();
    public DbSet<DialogueStep> DialogueSteps => Set<DialogueStep>();
    public DbSet<ScenarioAlias> ScenarioAliases => Set<ScenarioAlias>();
    public DbSet<AmbientSound> AmbientSounds => Set<AmbientSound>();
    public DbSet<Ringtone> Ringtones => Set<Ringtone>();
    public DbSet<Combo> Combos => Set<Combo>();
    public DbSet<ComboBackground> ComboBackgrounds => Set<ComboBackground>();
    public DbSet<Backup> Backups => Set<Backup>();
    public DbSet<SharePackage> SharePackages => Set<SharePackage>();
    public DbSet<SharePackageMedia> SharePackageMedia => Set<SharePackageMedia>();
    public DbSet<Entitlement> Entitlements => Set<Entitlement>();
    public DbSet<MarketPackage> MarketPackages => Set<MarketPackage>();
    public DbSet<MarketPurchase> MarketPurchases => Set<MarketPurchase>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(b =>
        {
            b.ToTable("Users");
            b.HasKey(x => x.Id);
            b.Property(x => x.Email).HasMaxLength(256).IsRequired();
            b.Property(x => x.NormalizedEmail).HasMaxLength(256).IsRequired();
            b.HasIndex(x => x.NormalizedEmail).IsUnique();
            b.Property(x => x.PasswordHash).IsRequired();
            b.Property(x => x.DisplayName).HasMaxLength(80).IsRequired();
            b.Property(x => x.Role).HasConversion<string>().HasMaxLength(20);
        });

        modelBuilder.Entity<RefreshToken>(b =>
        {
            b.ToTable("RefreshTokens");
            b.HasKey(x => x.Id);
            b.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
            b.HasIndex(x => x.TokenHash).IsUnique();
            b.Property(x => x.DeviceName).HasMaxLength(120);
            b.HasOne(x => x.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<UserSettings>(b =>
        {
            b.ToTable("UserSettings");
            b.HasKey(x => x.UserId);
            b.Property(x => x.ThemeMode).HasConversion<string>().HasMaxLength(20);
            b.HasOne(x => x.User)
                .WithOne(u => u.Settings)
                .HasForeignKey<UserSettings>(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<MediaFile>(b =>
        {
            b.ToTable("MediaFiles");
            b.HasKey(x => x.Id);
            b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(20);
            b.Property(x => x.OriginalName).HasMaxLength(255);
            b.Property(x => x.ContentType).HasMaxLength(80);
            b.Property(x => x.Extension).HasMaxLength(10);
            b.Property(x => x.Sha256).HasMaxLength(64);
            b.Property(x => x.StorageKey).HasMaxLength(260);
            b.Property(x => x.AssetKey).HasMaxLength(200);
            b.HasIndex(x => new { x.OwnerId, x.Sha256 });
            b.HasOne(x => x.Owner)
                .WithMany(u => u.MediaFiles)
                .HasForeignKey(x => x.OwnerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Scenario>(b =>
        {
            b.ToTable("Scenarios");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasMaxLength(64);
            b.Property(x => x.Title).HasMaxLength(80).IsRequired();
            b.Property(x => x.Category).HasConversion<string>().HasMaxLength(20);
            b.Property(x => x.Source).HasConversion<string>().HasMaxLength(20);
            b.Property(x => x.CallerName).HasMaxLength(40).IsRequired();
            b.Property(x => x.Initial).HasMaxLength(4).IsRequired();
            b.Property(x => x.DefaultAmbientSoundId).HasMaxLength(64);
            b.Property(x => x.CopiedFromScenarioId).HasMaxLength(64);
            b.HasIndex(x => x.OwnerId);
            b.HasOne(x => x.Owner)
                .WithMany(u => u.Scenarios)
                .HasForeignKey(x => x.OwnerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<DialogueStep>(b =>
        {
            b.ToTable("DialogueSteps");
            b.HasKey(x => new { x.ScenarioId, x.Id });
            b.Property(x => x.Id).HasMaxLength(64);
            b.Property(x => x.ScenarioId).HasMaxLength(64);
            b.Property(x => x.Type).HasConversion<string>().HasMaxLength(20);
            b.Property(x => x.Text).HasMaxLength(300).IsRequired();
            b.Property(x => x.AssetAudioPath).HasMaxLength(200);
            b.HasIndex(x => new { x.ScenarioId, x.Order }).IsUnique();
            b.HasOne(x => x.Scenario)
                .WithMany(s => s.Steps)
                .HasForeignKey(x => x.ScenarioId)
                .OnDelete(DeleteBehavior.Cascade);
            b.HasOne(x => x.MediaFile)
                .WithMany()
                .HasForeignKey(x => x.MediaFileId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<ScenarioAlias>(b =>
        {
            b.ToTable("ScenarioAliases");
            b.HasKey(x => x.LegacyId);
            b.Property(x => x.LegacyId).HasMaxLength(64);
            b.Property(x => x.ScenarioId).HasMaxLength(64);
            b.Property(x => x.FallbackTitle).HasMaxLength(80);
            b.Property(x => x.FallbackCaller).HasMaxLength(40);
            b.Property(x => x.FallbackDialogue).HasMaxLength(600);
        });

        modelBuilder.Entity<AmbientSound>(b =>
        {
            b.ToTable("AmbientSounds");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasMaxLength(64);
            b.Property(x => x.Title).HasMaxLength(60).IsRequired();
            b.Property(x => x.IconName).HasMaxLength(40);
            b.Property(x => x.AssetAudioPath).HasMaxLength(200);
            b.Property(x => x.LegacyKey).HasMaxLength(40);
            b.HasIndex(x => x.OwnerId);
            b.HasOne(x => x.Owner)
                .WithMany(u => u.AmbientSounds)
                .HasForeignKey(x => x.OwnerId)
                .OnDelete(DeleteBehavior.Cascade);
            b.HasOne(x => x.MediaFile)
                .WithMany()
                .HasForeignKey(x => x.MediaFileId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Ringtone>(b =>
        {
            b.ToTable("Ringtones");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasMaxLength(64);
            b.Property(x => x.Title).HasMaxLength(60).IsRequired();
            b.Property(x => x.AssetAudioPath).HasMaxLength(200).IsRequired();
        });

        modelBuilder.Entity<Combo>(b =>
        {
            b.ToTable("Combos");
            b.HasKey(x => new { x.OwnerId, x.Id });
            b.Property(x => x.Name).HasMaxLength(80).IsRequired();
            b.Property(x => x.ScenarioId).HasMaxLength(64).IsRequired();
            b.Property(x => x.CallInterface).HasConversion<string>().HasMaxLength(20);
            b.Property(x => x.RingtoneType).HasConversion<string>().HasMaxLength(20);
            b.Property(x => x.BackgroundVolume).HasPrecision(4, 2);
            b.HasOne(x => x.Owner)
                .WithMany(u => u.Combos)
                .HasForeignKey(x => x.OwnerId)
                .OnDelete(DeleteBehavior.Cascade);
            b.HasOne(x => x.RingtoneMedia)
                .WithMany()
                .HasForeignKey(x => x.RingtoneMediaId)
                .OnDelete(DeleteBehavior.NoAction);
            b.HasOne(x => x.CustomBackgroundMedia)
                .WithMany()
                .HasForeignKey(x => x.CustomBackgroundMediaId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<ComboBackground>(b =>
        {
            b.ToTable("ComboBackgrounds");
            b.HasKey(x => new { x.OwnerId, x.ComboId, x.AmbientSoundId });
            b.Property(x => x.AmbientSoundId).HasMaxLength(64);
            b.HasOne(x => x.Combo)
                .WithMany(c => c.Backgrounds)
                .HasForeignKey(x => new { x.OwnerId, x.ComboId })
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Backup>(b =>
        {
            b.ToTable("Backups");
            b.HasKey(x => x.Id);
            b.Property(x => x.DeviceName).HasMaxLength(120);
            b.Property(x => x.AppVersion).HasMaxLength(32);
            b.HasIndex(x => new { x.UserId, x.CreatedAt });
            b.HasOne(x => x.User)
                .WithMany(u => u.Backups)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SharePackage>(b =>
        {
            b.ToTable("SharePackages");
            b.HasKey(x => x.Id);
            b.Property(x => x.Code).HasMaxLength(16).IsRequired();
            b.HasIndex(x => x.Code).IsUnique();
            b.HasOne(x => x.CreatedBy)
                .WithMany(u => u.SharePackages)
                .HasForeignKey(x => x.CreatedById)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SharePackageMedia>(b =>
        {
            b.ToTable("SharePackageMedia");
            b.HasKey(x => new { x.SharePackageId, x.MediaFileId });
            b.HasOne(x => x.SharePackage)
                .WithMany(s => s.MediaItems)
                .HasForeignKey(x => x.SharePackageId)
                .OnDelete(DeleteBehavior.Cascade);
            b.HasOne(x => x.MediaFile)
                .WithMany()
                .HasForeignKey(x => x.MediaFileId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Entitlement>(b =>
        {
            b.ToTable("Entitlements");
            b.HasKey(x => x.Id);
            b.Property(x => x.Product).HasMaxLength(40);
            b.Property(x => x.Source).HasMaxLength(40);
            b.HasOne(x => x.User)
                .WithMany(u => u.Entitlements)
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<MarketPackage>(b =>
        {
            b.ToTable("MarketPackages");
            b.HasKey(x => x.Id);
            b.Property(x => x.Code).HasMaxLength(24).IsRequired();
            b.HasIndex(x => x.Code).IsUnique();
            b.Property(x => x.SellerName).HasMaxLength(80).IsRequired();
            b.Property(x => x.Title).HasMaxLength(100).IsRequired();
            b.Property(x => x.Description).HasMaxLength(500).IsRequired();
            b.Property(x => x.CategoryTag).HasMaxLength(40).IsRequired();
            b.Property(x => x.RatingAvg).HasPrecision(3, 2);
            b.HasOne(x => x.Seller)
                .WithMany()
                .HasForeignKey(x => x.SellerId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<MarketPurchase>(b =>
        {
            b.ToTable("MarketPurchases");
            b.HasKey(x => x.Id);
            b.HasIndex(x => new { x.MarketPackageId, x.BuyerId }).IsUnique();
            b.HasOne(x => x.MarketPackage)
                .WithMany(m => m.Purchases)
                .HasForeignKey(x => x.MarketPackageId)
                .OnDelete(DeleteBehavior.Cascade);
            b.HasOne(x => x.Buyer)
                .WithMany()
                .HasForeignKey(x => x.BuyerId)
                .OnDelete(DeleteBehavior.NoAction);
        });
    }
}
