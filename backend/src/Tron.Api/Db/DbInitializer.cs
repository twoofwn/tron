using Microsoft.EntityFrameworkCore;
using Serilog;
using Tron.Api.Models;

namespace Tron.Api.Db;

public static class DbInitializer
{
    public static async Task InitializeAsync(TronDbContext db, CancellationToken ct = default)
    {
        Log.Information("Ensuring database schema via Entity Framework Core...");

        try
        {
            // EnsureCreated creates all tables and constraints defined in TronDbContext
            // without requiring any .sql files or sysadmin/master privileges.
            await db.Database.EnsureCreatedAsync(ct);
            Log.Information("Database schema ensured successfully.");
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "EnsureCreated encountered a warning/notice (database schema may already exist). Proceeding with data seed check.");
        }

        // EnsureCreated không sửa bảng đã có, nên database tạo trước đó cần được bổ sung cột mới.
        await EnsureComboVoiceColumnAsync(db, ct);
        await EnsureComboVideoColumnsAsync(db, ct);

        // Seed seed data if missing
        await SeedAmbientSoundsAsync(db, ct);
        await SeedRingtonesAsync(db, ct);
        await SeedScenarioAliasesAsync(db, ct);
        await SeedScenariosAsync(db, ct);
        await SeedMarketPackagesAsync(db, ct);

        Log.Information("Database initialization and seed complete.");
    }

    /// <summary>
    /// Thêm cột Combos.VoiceMediaId (giọng người gọi tự thu) vào database cũ. Chạy lại nhiều lần vẫn an toàn.
    /// </summary>
    private static async Task EnsureComboVoiceColumnAsync(TronDbContext db, CancellationToken ct)
    {
        const string sql = """
            IF COL_LENGTH(N'dbo.Combos', N'VoiceMediaId') IS NULL
            BEGIN
                ALTER TABLE [dbo].[Combos] ADD [VoiceMediaId] UNIQUEIDENTIFIER NULL;
            END;
            IF OBJECT_ID(N'[dbo].[FK_Combos_MediaFiles_VoiceMediaId]', N'F') IS NULL
            BEGIN
                EXEC(N'ALTER TABLE [dbo].[Combos] ADD CONSTRAINT [FK_Combos_MediaFiles_VoiceMediaId]
                    FOREIGN KEY ([VoiceMediaId]) REFERENCES [dbo].[MediaFiles] ([Id])');
            END;
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Combos_VoiceMediaId' AND object_id = OBJECT_ID(N'dbo.Combos'))
            BEGIN
                EXEC(N'CREATE INDEX [IX_Combos_VoiceMediaId] ON [dbo].[Combos] ([VoiceMediaId])');
            END;
            """;
        try
        {
            await db.Database.ExecuteSqlRawAsync(sql, ct);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Could not add Combos.VoiceMediaId. Run the ALTER block in trondb.sql manually.");
            throw;
        }
    }

    /// <summary>
    /// Thêm cột Combos.CallType, VideoMediaId, CallerName, VideoEndAction (cuộc gọi video) vào database cũ. Chạy lại nhiều lần vẫn an toàn.
    /// </summary>
    private static async Task EnsureComboVideoColumnsAsync(TronDbContext db, CancellationToken ct)
    {
        const string sql = """
            IF COL_LENGTH(N'dbo.Combos', N'CallType') IS NULL
            BEGIN
                ALTER TABLE [dbo].[Combos] ADD [CallType] NVARCHAR(20) NOT NULL
                    CONSTRAINT [DF_Combos_CallType] DEFAULT (N'Voice');
            END;
            IF COL_LENGTH(N'dbo.Combos', N'VideoMediaId') IS NULL
            BEGIN
                ALTER TABLE [dbo].[Combos] ADD [VideoMediaId] UNIQUEIDENTIFIER NULL;
            END;
            IF OBJECT_ID(N'[dbo].[FK_Combos_MediaFiles_VideoMediaId]', N'F') IS NULL
            BEGIN
                EXEC(N'ALTER TABLE [dbo].[Combos] ADD CONSTRAINT [FK_Combos_MediaFiles_VideoMediaId]
                    FOREIGN KEY ([VideoMediaId]) REFERENCES [dbo].[MediaFiles] ([Id])');
            END;
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Combos_VideoMediaId' AND object_id = OBJECT_ID(N'dbo.Combos'))
            BEGIN
                EXEC(N'CREATE INDEX [IX_Combos_VideoMediaId] ON [dbo].[Combos] ([VideoMediaId])');
            END;
            IF COL_LENGTH(N'dbo.Combos', N'CallerName') IS NULL
            BEGIN
                ALTER TABLE [dbo].[Combos] ADD [CallerName] NVARCHAR(40) NULL;
            END;
            IF COL_LENGTH(N'dbo.Combos', N'VideoEndAction') IS NULL
            BEGIN
                ALTER TABLE [dbo].[Combos] ADD [VideoEndAction] NVARCHAR(20) NOT NULL
                    CONSTRAINT [DF_Combos_VideoEndAction] DEFAULT (N'HangUp');
            END;
            """;
        try
        {
            await db.Database.ExecuteSqlRawAsync(sql, ct);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Could not add Combos video columns. Run the ALTER block in trondb.sql manually.");
            throw;
        }
    }

    private static async Task SeedAmbientSoundsAsync(TronDbContext db, CancellationToken ct)
    {
        if (await db.AmbientSounds.AnyAsync(s => s.OwnerId == null, ct))
        {
            return;
        }

        Log.Information("Seeding default AmbientSounds...");
        db.AmbientSounds.AddRange(
            new AmbientSound { Id = "car", Title = "Còi xe", IconName = "car", AssetAudioPath = "audio/ambient/car.wav", LegacyKey = "traffic", SortOrder = 1 },
            new AmbientSound { Id = "television", Title = "Tiếng TV", IconName = "tv", AssetAudioPath = "audio/ambient/television.wav", LegacyKey = "television", SortOrder = 2 },
            new AmbientSound { Id = "office", Title = "Văn phòng", IconName = "office", AssetAudioPath = "audio/ambient/office.wav", LegacyKey = "office", SortOrder = 3 },
            new AmbientSound { Id = "rain", Title = "Trời mưa", IconName = "rain", AssetAudioPath = "audio/ambient/rain.wav", LegacyKey = "rain", SortOrder = 4 },
            new AmbientSound { Id = "dog", Title = "Chó sủa", IconName = "dog", AssetAudioPath = "audio/ambient/dog.wav", LegacyKey = null, SortOrder = 5 },
            new AmbientSound { Id = "cafe", Title = "Nhạc cà phê", IconName = "cafe", AssetAudioPath = "audio/ambient/cafe.wav", LegacyKey = "cafe", SortOrder = 6 },
            new AmbientSound { Id = "traffic", Title = "Còi xe (giao thông)", IconName = "car", AssetAudioPath = "assets/audio/backgrounds/traffic.wav", LegacyKey = "traffic", SortOrder = 7 }
        );
        await db.SaveChangesAsync(ct);
    }

    private static async Task SeedRingtonesAsync(TronDbContext db, CancellationToken ct)
    {
        if (await db.Ringtones.AnyAsync(ct))
        {
            return;
        }

        Log.Information("Seeding default Ringtones...");
        db.Ringtones.AddRange(
            new Ringtone { Id = "phone", Title = "Chuông Điện thoại", AssetAudioPath = "assets/audio/ringtones/phone_ring.wav", SortOrder = 1 },
            new Ringtone { Id = "zalo", Title = "Chuông Zalo", AssetAudioPath = "assets/audio/ringtones/zalo_ring.wav", SortOrder = 2 },
            new Ringtone { Id = "messenger", Title = "Chuông Messenger", AssetAudioPath = "assets/audio/ringtones/messenger_ring.wav", SortOrder = 3 },
            new Ringtone { Id = "classic", Title = "Chuông cổ điển", AssetAudioPath = "assets/audio/ringtones/classic_ring.wav", SortOrder = 4 }
        );
        await db.SaveChangesAsync(ct);
    }

    private static async Task SeedScenarioAliasesAsync(TronDbContext db, CancellationToken ct)
    {
        if (await db.ScenarioAliases.AnyAsync(ct))
        {
            return;
        }

        Log.Information("Seeding default ScenarioAliases...");
        db.ScenarioAliases.AddRange(
            new ScenarioAlias { LegacyId = "boss", ScenarioId = "boss-server" },
            new ScenarioAlias { LegacyId = "mother", ScenarioId = "mother-urgent" },
            new ScenarioAlias { LegacyId = "friend", ScenarioId = "friend-lan-demo" },
            new ScenarioAlias
            {
                LegacyId = "delivery",
                ScenarioId = "delivery",
                FallbackTitle = "Shipper đang chờ",
                FallbackCaller = "Giao hàng",
                FallbackDialogue = "A lô, em có đơn hàng giao cho anh chị. Em đang đứng trước cửa nhà rồi ạ. Anh chị về nhận giúp em nhé, đơn này cần ký nhận trực tiếp ạ."
            }
        );
        await db.SaveChangesAsync(ct);
    }

    private static async Task SeedScenariosAsync(TronDbContext db, CancellationToken ct)
    {
        if (await db.Scenarios.AnyAsync(s => s.OwnerId == null, ct))
        {
            return;
        }

        Log.Information("Seeding default Scenarios and DialogueSteps...");
        var mother = new Scenario
        {
            Id = "mother-urgent",
            Title = "Mẹ gọi về gấp",
            Category = ScenarioCategory.Family,
            Source = ScenarioSource.BuiltIn,
            CallerName = "Mẹ",
            Initial = "M",
            EstimatedSeconds = 40,
            DefaultAmbientSoundId = "television",
            IsPro = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Steps = new List<DialogueStep>
            {
                new() { Id = "m1", ScenarioId = "mother-urgent", Order = 1, Type = DialogueStepType.Speech, Text = "Alo, con à?", AssetAudioPath = "audio/voice/mother_1.wav", Seconds = 2 },
                new() { Id = "mw1", ScenarioId = "mother-urgent", Order = 2, Type = DialogueStepType.Wait, Text = "Bạn trả lời · chạm để tiếp tục", Seconds = 0 },
                new() { Id = "m2", ScenarioId = "mother-urgent", Order = 3, Type = DialogueStepType.Speech, Text = "Ở nhà có việc gấp, con về ngay nhé.", AssetAudioPath = "audio/voice/mother_2.wav", Seconds = 4 },
                new() { Id = "mw2", ScenarioId = "mother-urgent", Order = 4, Type = DialogueStepType.Wait, Text = "Bạn trả lời · chạm để tiếp tục", Seconds = 0 },
                new() { Id = "m3", ScenarioId = "mother-urgent", Order = 5, Type = DialogueStepType.Speech, Text = "Không được, bố con đang mệt. Về liền đi.", AssetAudioPath = "audio/voice/mother_3.wav", Seconds = 3 },
                new() { Id = "m4", ScenarioId = "mother-urgent", Order = 6, Type = DialogueStepType.Speech, Text = "Nhanh lên nhé con.", AssetAudioPath = "audio/voice/mother_4.wav", Seconds = 2 }
            }
        };

        var boss = new Scenario
        {
            Id = "boss-server",
            Title = "Sếp báo server sập",
            Category = ScenarioCategory.Work,
            Source = ScenarioSource.BuiltIn,
            CallerName = "Sếp Hùng",
            Initial = "S",
            EstimatedSeconds = 55,
            DefaultAmbientSoundId = "office",
            IsPro = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Steps = new List<DialogueStep>
            {
                new() { Id = "b1", ScenarioId = "boss-server", Order = 1, Type = DialogueStepType.Speech, Text = "Alo, em nghe máy được không?", AssetAudioPath = "audio/voice/boss_1.wav", Seconds = 2 },
                new() { Id = "bw1", ScenarioId = "boss-server", Order = 2, Type = DialogueStepType.Wait, Text = "Bạn trả lời · chạm để tiếp tục", Seconds = 0 },
                new() { Id = "b2", ScenarioId = "boss-server", Order = 3, Type = DialogueStepType.Speech, Text = "Server bên mình vừa gặp sự cố, cần em kiểm tra ngay.", AssetAudioPath = "audio/voice/boss_2.wav", Seconds = 4 },
                new() { Id = "b3", ScenarioId = "boss-server", Order = 4, Type = DialogueStepType.Speech, Text = "Em có thể về máy tính trong ít phút nữa không?", AssetAudioPath = "audio/voice/boss_3.wav", Seconds = 4 },
                new() { Id = "bw2", ScenarioId = "boss-server", Order = 5, Type = DialogueStepType.Wait, Text = "Bạn trả lời · chạm để tiếp tục", Seconds = 0 },
                new() { Id = "b4", ScenarioId = "boss-server", Order = 6, Type = DialogueStepType.Speech, Text = "Ừ, anh chờ em. Cảm ơn nhé.", AssetAudioPath = "audio/voice/boss_4.wav", Seconds = 3 },
                new() { Id = "b5", ScenarioId = "boss-server", Order = 7, Type = DialogueStepType.Speech, Text = "Có gì cập nhật thì gọi lại cho anh.", AssetAudioPath = "audio/voice/boss_5.wav", Seconds = 3 }
            }
        };

        var landlord = new Scenario
        {
            Id = "landlord-rent",
            Title = "Chủ trọ đòi tiền nhà",
            Category = ScenarioCategory.Family,
            Source = ScenarioSource.BuiltIn,
            CallerName = "Chủ trọ",
            Initial = "C",
            EstimatedSeconds = 35,
            DefaultAmbientSoundId = "office",
            IsPro = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Steps = new List<DialogueStep>
            {
                new() { Id = "l1", ScenarioId = "landlord-rent", Order = 1, Type = DialogueStepType.Speech, Text = "Alo, cô gọi về tiền phòng tháng này.", AssetAudioPath = "audio/voice/landlord_1.wav", Seconds = 3 },
                new() { Id = "lw1", ScenarioId = "landlord-rent", Order = 2, Type = DialogueStepType.Wait, Text = "Bạn trả lời · chạm để tiếp tục", Seconds = 0 },
                new() { Id = "l2", ScenarioId = "landlord-rent", Order = 3, Type = DialogueStepType.Speech, Text = "Con thu xếp về gặp cô hôm nay nhé.", AssetAudioPath = "audio/voice/landlord_2.wav", Seconds = 3 },
                new() { Id = "l3", ScenarioId = "landlord-rent", Order = 4, Type = DialogueStepType.Speech, Text = "Cô cần nói chuyện trực tiếp một chút.", AssetAudioPath = "audio/voice/landlord_3.wav", Seconds = 3 },
                new() { Id = "l4", ScenarioId = "landlord-rent", Order = 5, Type = DialogueStepType.Speech, Text = "Cô đợi con ở nhà trọ.", AssetAudioPath = "audio/voice/landlord_4.wav", Seconds = 2 }
            }
        };

        var friend = new Scenario
        {
            Id = "friend-lan-demo",
            Title = "Lan (bạn thân) – mẫu tự tạo",
            Category = ScenarioCategory.Personal,
            Source = ScenarioSource.SampleUser,
            CallerName = "Lan",
            Initial = "L",
            EstimatedSeconds = 30,
            DefaultAmbientSoundId = "cafe",
            IsPro = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Steps = new List<DialogueStep>
            {
                new() { Id = "f1", ScenarioId = "friend-lan-demo", Order = 1, Type = DialogueStepType.Speech, Text = "Ê, cậu ra ngoài gặp mình một lát được không?", AssetAudioPath = "audio/voice/friend_1.wav", Seconds = 3 },
                new() { Id = "fw1", ScenarioId = "friend-lan-demo", Order = 2, Type = DialogueStepType.Wait, Text = "Bạn trả lời · chạm để tiếp tục", Seconds = 0 },
                new() { Id = "f2", ScenarioId = "friend-lan-demo", Order = 3, Type = DialogueStepType.Speech, Text = "Mình đang có chuyện gấp muốn hỏi cậu.", AssetAudioPath = "audio/voice/friend_2.wav", Seconds = 3 },
                new() { Id = "f3", ScenarioId = "friend-lan-demo", Order = 4, Type = DialogueStepType.Speech, Text = "Ra chỗ cũ nhé, mình đợi.", AssetAudioPath = "audio/voice/friend_3.wav", Seconds = 2 }
            }
        };

        db.Scenarios.AddRange(mother, boss, landlord, friend);
        await db.SaveChangesAsync(ct);
    }

    private static async Task SeedMarketPackagesAsync(TronDbContext db, CancellationToken ct)
    {
        if (await db.MarketPackages.AnyAsync(ct))
        {
            return;
        }

        Log.Information("Seeding default MarketPackages...");
        db.MarketPackages.AddRange(
            new MarketPackage
            {
                Id = Guid.Parse("A1111111-1111-4111-8111-111111111111"),
                Code = "MKT-WORK-PRO",
                SellerId = null,
                SellerName = "TRỐN Official",
                IsOfficial = true,
                Title = "Gói Thoát Họp & Tăng Ca Khẩn Cấp",
                Description = "Bộ combo cứu nguy công sở chính hãng: Sếp gọi xử lý sự cố Server gấp và Khách hàng VIP yêu cầu hỗ trợ ngay lập tức.",
                CategoryTag = "Công việc",
                PriceVnd = 29000,
                ComboCount = 2,
                ScenarioCount = 1,
                DownloadCount = 412,
                RatingAvg = 4.95m,
                PayloadJson = "{\"combos\":[{\"id\":\"11111111-2222-4333-8444-555555555501\",\"name\":\"Sếp gọi xử lý Server gấp\",\"scenarioId\":\"boss-server\",\"callInterface\":\"zalo\",\"ringtoneType\":\"interfaceDefault\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"office\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.3,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-01T00:00:00Z\"},{\"id\":\"11111111-2222-4333-8444-555555555502\",\"name\":\"Khách VIP báo lỗi hợp đồng\",\"scenarioId\":\"mkt-vip-client\",\"callInterface\":\"phone\",\"ringtoneType\":\"classic\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"office\",\"cafe\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.3,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-01T00:00:00Z\"}],\"customScenarios\":[{\"id\":\"mkt-vip-client\",\"title\":\"Khách VIP báo lỗi hợp đồng\",\"category\":\"work\",\"source\":\"user\",\"callerName\":\"Anh Minh (Đối tác)\",\"initial\":\"M\",\"estimatedSeconds\":35,\"defaultBackgroundId\":\"office\",\"isPro\":false,\"steps\":[{\"id\":\"s1\",\"type\":\"speech\",\"text\":\"Alo, bên anh vừa phát hiện sai số liệu trong phụ lục hợp đồng chiều nay.\",\"audioPath\":\"audio/voice/boss_1.wav\",\"mediaFileId\":null,\"seconds\":4},{\"id\":\"s2\",\"type\":\"wait\",\"text\":\"Bạn trả lời · chạm để tiếp tục\",\"audioPath\":null,\"mediaFileId\":null,\"seconds\":0},{\"id\":\"s3\",\"type\":\"speech\",\"text\":\"Em về mở máy kiểm tra và gửi lại bản chỉnh sửa trong 15 phút giúp anh nhé.\",\"audioPath\":\"audio/voice/boss_2.wav\",\"mediaFileId\":null,\"seconds\":4}]}],\"customAmbientSounds\":[]}",
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            },
            new MarketPackage
            {
                Id = Guid.Parse("A2222222-2222-4222-8222-222222222222"),
                Code = "MKT-PARTY-VIP",
                SellerId = null,
                SellerName = "TRỐN Official",
                IsOfficial = true,
                Title = "Gói Giải Cứu Tiệc Rượu & Hẹn Hò",
                Description = "Dành cho các buổi tiệc kéo dài hoặc cuộc hẹn khó xử: Mẹ gọi về nhà gấp kèm âm nền TV gia đình và Bạn thân nhờ ra đón.",
                CategoryTag = "Tiệc tùng",
                PriceVnd = 19000,
                ComboCount = 2,
                ScenarioCount = 0,
                DownloadCount = 589,
                RatingAvg = 4.90m,
                PayloadJson = "{\"combos\":[{\"id\":\"22222222-2222-4333-8444-555555555501\",\"name\":\"Mẹ gọi về nhà ngay\",\"scenarioId\":\"mother-urgent\",\"callInterface\":\"phone\",\"ringtoneType\":\"classic\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"television\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.35,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-02T00:00:00Z\"},{\"id\":\"22222222-2222-4333-8444-555555555502\",\"name\":\"Bạn thân đứng đợi dưới sảnh\",\"scenarioId\":\"friend-lan-demo\",\"callInterface\":\"messenger\",\"ringtoneType\":\"interfaceDefault\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"car\",\"cafe\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.3,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-02T00:00:00Z\"}],\"customScenarios\":[],\"customAmbientSounds\":[]}",
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            },
            new MarketPackage
            {
                Id = Guid.Parse("A3333333-3333-4333-8333-333333333333"),
                Code = "MKT-HOME-FREE",
                SellerId = null,
                SellerName = "TRỐN Official",
                IsOfficial = true,
                Title = "Gói Chủ Trọ & Shipper Giao Hàng",
                Description = "Gói miễn phí từ nhà sản xuất: Chủ nhà gọi về kiểm tra phòng và Shipper giao đơn hỏa tốc cần nhận trực tiếp.",
                CategoryTag = "Gia đình",
                PriceVnd = 0,
                ComboCount = 2,
                ScenarioCount = 1,
                DownloadCount = 830,
                RatingAvg = 4.85m,
                PayloadJson = "{\"combos\":[{\"id\":\"33333333-2222-4333-8444-555555555501\",\"name\":\"Chủ nhà báo kiểm tra phòng\",\"scenarioId\":\"landlord-rent\",\"callInterface\":\"phone\",\"ringtoneType\":\"interfaceDefault\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"rain\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.3,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-03T00:00:00Z\"},{\"id\":\"33333333-2222-4333-8444-555555555502\",\"name\":\"Shipper giao đơn hỏa tốc\",\"scenarioId\":\"mkt-shipper-express\",\"callInterface\":\"zalo\",\"ringtoneType\":\"interfaceDefault\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"car\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.3,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-03T00:00:00Z\"}],\"customScenarios\":[{\"id\":\"mkt-shipper-express\",\"title\":\"Shipper giao đơn hỏa tốc\",\"category\":\"personal\",\"source\":\"user\",\"callerName\":\"Shipper Giao Hàng\",\"initial\":\"S\",\"estimatedSeconds\":25,\"defaultBackgroundId\":\"car\",\"isPro\":false,\"steps\":[{\"id\":\"sh1\",\"type\":\"speech\",\"text\":\"Alo anh chị ơi, em giao đơn hỏa tốc đang đứng trước cổng rồi ạ.\",\"audioPath\":\"audio/voice/friend_1.wav\",\"mediaFileId\":null,\"seconds\":3},{\"id\":\"sh2\",\"type\":\"wait\",\"text\":\"Bạn trả lời · chạm để tiếp tục\",\"audioPath\":null,\"mediaFileId\":null,\"seconds\":0},{\"id\":\"sh3\",\"type\":\"speech\",\"text\":\"Đơn này giá trị cao cần ký nhận trực tiếp, anh chị ra nhận giúp em liền nhé.\",\"audioPath\":\"audio/voice/friend_2.wav\",\"mediaFileId\":null,\"seconds\":4}]}],\"customAmbientSounds\":[]}",
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            },
            new MarketPackage
            {
                Id = Guid.Parse("A4444444-4444-4444-8444-444444444444"),
                Code = "MKT-COMM-01",
                SellerId = null,
                SellerName = "Minh Tuấn (Cộng đồng)",
                IsOfficial = false,
                Title = "Combo Ra Khỏi Cuộc Nhậu Êm Đẹp",
                Description = "Kịch bản vợ/người yêu gọi về đón gấp kèm tiếng mưa và còi xe cực chân thật do người dùng chia sẻ.",
                CategoryTag = "Cộng đồng",
                PriceVnd = 15000,
                ComboCount = 1,
                ScenarioCount = 1,
                DownloadCount = 196,
                RatingAvg = 4.80m,
                PayloadJson = "{\"combos\":[{\"id\":\"44444444-2222-4333-8444-555555555501\",\"name\":\"Người thương gọi đón gấp\",\"scenarioId\":\"mkt-partner-pickup\",\"callInterface\":\"messenger\",\"ringtoneType\":\"interfaceDefault\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"rain\",\"car\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.35,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-04T00:00:00Z\"}],\"customScenarios\":[{\"id\":\"mkt-partner-pickup\",\"title\":\"Người thương gọi đón gấp\",\"category\":\"family\",\"source\":\"user\",\"callerName\":\"Vợ Yêu\",\"initial\":\"V\",\"estimatedSeconds\":30,\"defaultBackgroundId\":\"rain\",\"isPro\":false,\"steps\":[{\"id\":\"p1\",\"type\":\"speech\",\"text\":\"Alo, trời mưa to quá mà xe em lại hết bình, anh qua đón em về ngay được không?\",\"audioPath\":\"audio/voice/mother_1.wav\",\"mediaFileId\":null,\"seconds\":4},{\"id\":\"p2\",\"type\":\"wait\",\"text\":\"Bạn trả lời · chạm để tiếp tục\",\"audioPath\":null,\"mediaFileId\":null,\"seconds\":0},{\"id\":\"p3\",\"type\":\"speech\",\"text\":\"Em đang đứng đợi ở sảnh tòa nhà, anh về liền nhé.\",\"audioPath\":\"audio/voice/mother_2.wav\",\"mediaFileId\":null,\"seconds\":3}]}],\"customAmbientSounds\":[]}",
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            },
            new MarketPackage
            {
                Id = Guid.Parse("A5555555-5555-4555-8555-555555555555"),
                Code = "MKT-COMM-02",
                SellerId = null,
                SellerName = "Hoàng Yến (Cộng đồng)",
                IsOfficial = false,
                Title = "Combo Đội Nhóm Gọi Chạy Deadline",
                Description = "Dành cho sinh viên và freelancer rút lui lịch sự khi đang ngồi cà phê hoặc tụ tập quá lâu.",
                CategoryTag = "Cộng đồng",
                PriceVnd = 0,
                ComboCount = 1,
                ScenarioCount = 0,
                DownloadCount = 324,
                RatingAvg = 4.75m,
                PayloadJson = "{\"combos\":[{\"id\":\"55555555-2222-4333-8444-555555555501\",\"name\":\"Leader gọi họp nhóm gấp\",\"scenarioId\":\"boss-server\",\"callInterface\":\"zalo\",\"ringtoneType\":\"interfaceDefault\",\"ringtoneMediaId\":null,\"backgroundSoundIds\":[\"cafe\"],\"customBackgroundMediaId\":null,\"backgroundVolume\":0.25,\"backgroundOverridden\":false,\"createdAt\":\"2026-10-05T00:00:00Z\"}],\"customScenarios\":[],\"customAmbientSounds\":[]}",
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            }
        );
        await db.SaveChangesAsync(ct);
    }
}
