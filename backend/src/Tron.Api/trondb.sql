-- =============================================================================
-- TRỐN (EscapeHatch) - SQL Server Database Creation & Seed Script (trondb.sql)
-- Target DBMS: Microsoft SQL Server 2019 / 2022
-- =============================================================================

USE [master];
GO

IF DB_ID(N'TronDb') IS NULL
BEGIN
    CREATE DATABASE [TronDb];
END
GO

USE [TronDb];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- =============================================================================
-- 1. TABLES & CONSTRAINTS
-- =============================================================================

-- 1.1 Users
IF OBJECT_ID(N'[dbo].[Users]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Users] (
        [Id]              UNIQUEIDENTIFIER NOT NULL,
        [Email]           NVARCHAR(256)    NOT NULL,
        [NormalizedEmail] NVARCHAR(256)    NOT NULL,
        [PasswordHash]    NVARCHAR(MAX)    NOT NULL,
        [DisplayName]     NVARCHAR(80)     NOT NULL,
        [Role]            NVARCHAR(20)     NOT NULL DEFAULT N'User',
        [IsActive]        BIT              NOT NULL DEFAULT (1),
        [FailedLoginCount] INT             NOT NULL DEFAULT (0),
        [LockoutEnd]      DATETIME2        NULL,
        [CreatedAt]       DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [LastLoginAt]     DATETIME2        NULL,
        CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
    );

    CREATE UNIQUE INDEX [IX_Users_NormalizedEmail] ON [dbo].[Users] ([NormalizedEmail]);
END
GO

-- 1.2 RefreshTokens
IF OBJECT_ID(N'[dbo].[RefreshTokens]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[RefreshTokens] (
        [Id]           UNIQUEIDENTIFIER NOT NULL,
        [UserId]       UNIQUEIDENTIFIER NOT NULL,
        [TokenHash]    NVARCHAR(64)     NOT NULL,
        [DeviceName]   NVARCHAR(120)    NOT NULL,
        [CreatedAt]    DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [ExpiresAt]    DATETIME2        NOT NULL,
        [RevokedAt]    DATETIME2        NULL,
        [ReplacedById] UNIQUEIDENTIFIER NULL,
        CONSTRAINT [PK_RefreshTokens] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_RefreshTokens_Users_UserId] FOREIGN KEY ([UserId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );

    CREATE UNIQUE INDEX [IX_RefreshTokens_TokenHash] ON [dbo].[RefreshTokens] ([TokenHash]);
    CREATE INDEX [IX_RefreshTokens_UserId] ON [dbo].[RefreshTokens] ([UserId]);
END
GO

-- 1.3 UserSettings
IF OBJECT_ID(N'[dbo].[UserSettings]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[UserSettings] (
        [UserId]                  UNIQUEIDENTIFIER NOT NULL,
        [ThemeMode]               NVARCHAR(20)     NOT NULL DEFAULT N'Dark',
        [DefaultCallDelaySeconds] INT              NOT NULL DEFAULT (30),
        [UpdatedAt]               DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_UserSettings] PRIMARY KEY ([UserId]),
        CONSTRAINT [FK_UserSettings_Users_UserId] FOREIGN KEY ([UserId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );
END
GO

-- 1.4 MediaFiles
IF OBJECT_ID(N'[dbo].[MediaFiles]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MediaFiles] (
        [Id]           UNIQUEIDENTIFIER NOT NULL,
        [OwnerId]      UNIQUEIDENTIFIER NULL,
        [Kind]         NVARCHAR(20)     NOT NULL,
        [OriginalName] NVARCHAR(255)    NOT NULL,
        [ContentType]  NVARCHAR(80)     NOT NULL,
        [Extension]    NVARCHAR(10)     NOT NULL,
        [SizeBytes]    BIGINT           NOT NULL,
        [Sha256]       NVARCHAR(64)     NOT NULL,
        [StorageKey]   NVARCHAR(260)    NOT NULL,
        [AssetKey]     NVARCHAR(200)    NULL,
        [CreatedAt]    DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [OrphanedAt]   DATETIME2        NULL,
        CONSTRAINT [PK_MediaFiles] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_MediaFiles_Users_OwnerId] FOREIGN KEY ([OwnerId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );

    CREATE INDEX [IX_MediaFiles_OwnerId_Sha256] ON [dbo].[MediaFiles] ([OwnerId], [Sha256]);
END
GO

-- 1.5 Scenarios
IF OBJECT_ID(N'[dbo].[Scenarios]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Scenarios] (
        [Id]                    NVARCHAR(64)     NOT NULL,
        [OwnerId]               UNIQUEIDENTIFIER NULL,
        [Title]                 NVARCHAR(80)     NOT NULL,
        [Category]              NVARCHAR(20)     NOT NULL,
        [Source]                NVARCHAR(20)     NOT NULL,
        [CallerName]            NVARCHAR(40)     NOT NULL,
        [Initial]               NVARCHAR(4)      NOT NULL,
        [EstimatedSeconds]      INT              NULL,
        [DefaultAmbientSoundId] NVARCHAR(64)     NULL,
        [IsPro]                 BIT              NOT NULL DEFAULT (0),
        [CopiedFromScenarioId]  NVARCHAR(64)     NULL,
        [CreatedAt]             DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]             DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Scenarios] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Scenarios_Users_OwnerId] FOREIGN KEY ([OwnerId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );

    CREATE INDEX [IX_Scenarios_OwnerId] ON [dbo].[Scenarios] ([OwnerId]);
END
GO

-- 1.6 DialogueSteps
IF OBJECT_ID(N'[dbo].[DialogueSteps]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[DialogueSteps] (
        [ScenarioId]     NVARCHAR(64)     NOT NULL,
        [Id]             NVARCHAR(64)     NOT NULL,
        [Order]          INT              NOT NULL,
        [Type]           NVARCHAR(20)     NOT NULL,
        [Text]           NVARCHAR(300)    NOT NULL,
        [MediaFileId]    UNIQUEIDENTIFIER NULL,
        [AssetAudioPath] NVARCHAR(200)    NULL,
        [Seconds]        INT              NOT NULL DEFAULT (0),
        CONSTRAINT [PK_DialogueSteps] PRIMARY KEY ([ScenarioId], [Id]),
        CONSTRAINT [FK_DialogueSteps_Scenarios_ScenarioId] FOREIGN KEY ([ScenarioId])
            REFERENCES [dbo].[Scenarios] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_DialogueSteps_MediaFiles_MediaFileId] FOREIGN KEY ([MediaFileId])
            REFERENCES [dbo].[MediaFiles] ([Id])
    );

    CREATE UNIQUE INDEX [IX_DialogueSteps_ScenarioId_Order] ON [dbo].[DialogueSteps] ([ScenarioId], [Order]);
    CREATE INDEX [IX_DialogueSteps_MediaFileId] ON [dbo].[DialogueSteps] ([MediaFileId]);
END
GO

-- 1.7 ScenarioAliases
IF OBJECT_ID(N'[dbo].[ScenarioAliases]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ScenarioAliases] (
        [LegacyId]         NVARCHAR(64)  NOT NULL,
        [ScenarioId]       NVARCHAR(64)  NOT NULL,
        [FallbackTitle]    NVARCHAR(80)  NULL,
        [FallbackCaller]   NVARCHAR(40)  NULL,
        [FallbackDialogue] NVARCHAR(600) NULL,
        CONSTRAINT [PK_ScenarioAliases] PRIMARY KEY ([LegacyId])
    );
END
GO

-- 1.8 AmbientSounds
IF OBJECT_ID(N'[dbo].[AmbientSounds]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[AmbientSounds] (
        [Id]             NVARCHAR(64)     NOT NULL,
        [OwnerId]        UNIQUEIDENTIFIER NULL,
        [Title]          NVARCHAR(60)     NOT NULL,
        [IconName]       NVARCHAR(40)     NOT NULL DEFAULT N'music',
        [MediaFileId]    UNIQUEIDENTIFIER NULL,
        [AssetAudioPath] NVARCHAR(200)    NULL,
        [LegacyKey]      NVARCHAR(40)     NULL,
        [SortOrder]      INT              NOT NULL DEFAULT (0),
        [CreatedAt]      DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_AmbientSounds] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_AmbientSounds_Users_OwnerId] FOREIGN KEY ([OwnerId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_AmbientSounds_MediaFiles_MediaFileId] FOREIGN KEY ([MediaFileId])
            REFERENCES [dbo].[MediaFiles] ([Id])
    );

    CREATE INDEX [IX_AmbientSounds_OwnerId] ON [dbo].[AmbientSounds] ([OwnerId]);
    CREATE INDEX [IX_AmbientSounds_MediaFileId] ON [dbo].[AmbientSounds] ([MediaFileId]);
END
GO

-- 1.9 Ringtones
IF OBJECT_ID(N'[dbo].[Ringtones]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Ringtones] (
        [Id]             NVARCHAR(64)  NOT NULL,
        [Title]          NVARCHAR(60)  NOT NULL,
        [AssetAudioPath] NVARCHAR(200) NOT NULL,
        [SortOrder]      INT           NOT NULL DEFAULT (0),
        CONSTRAINT [PK_Ringtones] PRIMARY KEY ([Id])
    );
END
GO

-- 1.10 Combos
IF OBJECT_ID(N'[dbo].[Combos]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Combos] (
        [OwnerId]                 UNIQUEIDENTIFIER NOT NULL,
        [Id]                      UNIQUEIDENTIFIER NOT NULL,
        [Name]                    NVARCHAR(80)     NOT NULL,
        [ScenarioId]              NVARCHAR(64)     NOT NULL,
        [CallInterface]           NVARCHAR(20)     NOT NULL,
        [CallType]                NVARCHAR(20)     NOT NULL CONSTRAINT [DF_Combos_CallType] DEFAULT (N'Voice'),
        [RingtoneType]            NVARCHAR(20)     NOT NULL,
        [RingtoneMediaId]         UNIQUEIDENTIFIER NULL,
        [CustomBackgroundMediaId] UNIQUEIDENTIFIER NULL,
        [VoiceMediaId]            UNIQUEIDENTIFIER NULL,
        [VideoMediaId]            UNIQUEIDENTIFIER NULL,
        [CallerName]              NVARCHAR(40)     NULL,
        [VideoEndAction]          NVARCHAR(20)     NOT NULL CONSTRAINT [DF_Combos_VideoEndAction] DEFAULT (N'HangUp'),
        [BackgroundVolume]        DECIMAL(4, 2)    NOT NULL DEFAULT (0.30),
        [BackgroundOverridden]    BIT              NOT NULL DEFAULT (0),
        [SortOrder]               INT              NOT NULL DEFAULT (0),
        [CreatedAt]               DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]               DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Combos] PRIMARY KEY ([OwnerId], [Id]),
        CONSTRAINT [FK_Combos_Users_OwnerId] FOREIGN KEY ([OwnerId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_Combos_MediaFiles_RingtoneMediaId] FOREIGN KEY ([RingtoneMediaId])
            REFERENCES [dbo].[MediaFiles] ([Id]),
        CONSTRAINT [FK_Combos_MediaFiles_CustomBackgroundMediaId] FOREIGN KEY ([CustomBackgroundMediaId])
            REFERENCES [dbo].[MediaFiles] ([Id]),
        CONSTRAINT [FK_Combos_MediaFiles_VoiceMediaId] FOREIGN KEY ([VoiceMediaId])
            REFERENCES [dbo].[MediaFiles] ([Id]),
        CONSTRAINT [FK_Combos_MediaFiles_VideoMediaId] FOREIGN KEY ([VideoMediaId])
            REFERENCES [dbo].[MediaFiles] ([Id])
    );

    CREATE INDEX [IX_Combos_RingtoneMediaId] ON [dbo].[Combos] ([RingtoneMediaId]);
    CREATE INDEX [IX_Combos_CustomBackgroundMediaId] ON [dbo].[Combos] ([CustomBackgroundMediaId]);
    CREATE INDEX [IX_Combos_VoiceMediaId] ON [dbo].[Combos] ([VoiceMediaId]);
    CREATE INDEX [IX_Combos_VideoMediaId] ON [dbo].[Combos] ([VideoMediaId]);
END
GO

-- 1.10b Nâng cấp database cũ: thêm cột giọng người gọi tự thu
IF COL_LENGTH(N'dbo.Combos', N'VoiceMediaId') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD [VoiceMediaId] UNIQUEIDENTIFIER NULL;
END
GO
IF OBJECT_ID(N'[dbo].[FK_Combos_MediaFiles_VoiceMediaId]', N'F') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD CONSTRAINT [FK_Combos_MediaFiles_VoiceMediaId]
        FOREIGN KEY ([VoiceMediaId]) REFERENCES [dbo].[MediaFiles] ([Id]);
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Combos_VoiceMediaId' AND object_id = OBJECT_ID(N'dbo.Combos'))
BEGIN
    CREATE INDEX [IX_Combos_VoiceMediaId] ON [dbo].[Combos] ([VoiceMediaId]);
END
GO

-- 1.10c Nâng cấp database cũ: thêm loại cuộc gọi (thoại/video) và video người gọi tự quay
IF COL_LENGTH(N'dbo.Combos', N'CallType') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD [CallType] NVARCHAR(20) NOT NULL
        CONSTRAINT [DF_Combos_CallType] DEFAULT (N'Voice');
END
GO
IF COL_LENGTH(N'dbo.Combos', N'VideoMediaId') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD [VideoMediaId] UNIQUEIDENTIFIER NULL;
END
GO
IF OBJECT_ID(N'[dbo].[FK_Combos_MediaFiles_VideoMediaId]', N'F') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD CONSTRAINT [FK_Combos_MediaFiles_VideoMediaId]
        FOREIGN KEY ([VideoMediaId]) REFERENCES [dbo].[MediaFiles] ([Id]);
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Combos_VideoMediaId' AND object_id = OBJECT_ID(N'dbo.Combos'))
BEGIN
    CREATE INDEX [IX_Combos_VideoMediaId] ON [dbo].[Combos] ([VideoMediaId]);
END
GO

-- 1.10d Nâng cấp database cũ: tên người gọi và cách kết thúc của cuộc gọi video
IF COL_LENGTH(N'dbo.Combos', N'CallerName') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD [CallerName] NVARCHAR(40) NULL;
END
GO
IF COL_LENGTH(N'dbo.Combos', N'VideoEndAction') IS NULL
BEGIN
    ALTER TABLE [dbo].[Combos] ADD [VideoEndAction] NVARCHAR(20) NOT NULL
        CONSTRAINT [DF_Combos_VideoEndAction] DEFAULT (N'HangUp');
END
GO

-- 1.11 ComboBackgrounds
IF OBJECT_ID(N'[dbo].[ComboBackgrounds]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ComboBackgrounds] (
        [OwnerId]        UNIQUEIDENTIFIER NOT NULL,
        [ComboId]        UNIQUEIDENTIFIER NOT NULL,
        [AmbientSoundId] NVARCHAR(64)     NOT NULL,
        [Order]          INT              NOT NULL DEFAULT (0),
        CONSTRAINT [PK_ComboBackgrounds] PRIMARY KEY ([OwnerId], [ComboId], [AmbientSoundId]),
        CONSTRAINT [FK_ComboBackgrounds_Combos_OwnerId_ComboId] FOREIGN KEY ([OwnerId], [ComboId])
            REFERENCES [dbo].[Combos] ([OwnerId], [Id]) ON DELETE CASCADE
    );
END
GO

-- 1.12 Backups
IF OBJECT_ID(N'[dbo].[Backups]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Backups] (
        [Id]              UNIQUEIDENTIFIER NOT NULL,
        [UserId]          UNIQUEIDENTIFIER NOT NULL,
        [CreatedAt]       DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [DeviceName]      NVARCHAR(120)    NOT NULL,
        [AppVersion]      NVARCHAR(32)     NOT NULL,
        [ComboCount]      INT              NOT NULL DEFAULT (0),
        [ScenarioCount]   INT              NOT NULL DEFAULT (0),
        [AmbientCount]    INT              NOT NULL DEFAULT (0),
        [MediaCount]      INT              NOT NULL DEFAULT (0),
        [TotalMediaBytes] BIGINT           NOT NULL DEFAULT (0),
        CONSTRAINT [PK_Backups] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Backups_Users_UserId] FOREIGN KEY ([UserId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );

    CREATE INDEX [IX_Backups_UserId_CreatedAt] ON [dbo].[Backups] ([UserId], [CreatedAt]);
END
GO

-- 1.13 SharePackages
IF OBJECT_ID(N'[dbo].[SharePackages]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[SharePackages] (
        [Id]            UNIQUEIDENTIFIER NOT NULL,
        [Code]          NVARCHAR(16)     NOT NULL,
        [CreatedById]   UNIQUEIDENTIFIER NOT NULL,
        [SnapshotJson]  NVARCHAR(MAX)    NOT NULL,
        [IncludesAudio] BIT              NOT NULL DEFAULT (0),
        [ComboCount]    INT              NOT NULL DEFAULT (0),
        [SizeBytes]     BIGINT           NOT NULL DEFAULT (0),
        [CreatedAt]     DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [ExpiresAt]     DATETIME2        NOT NULL,
        [MaxImports]    INT              NULL,
        [ImportCount]   INT              NOT NULL DEFAULT (0),
        [RevokedAt]     DATETIME2        NULL,
        CONSTRAINT [PK_SharePackages] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_SharePackages_Users_CreatedById] FOREIGN KEY ([CreatedById])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );

    CREATE UNIQUE INDEX [IX_SharePackages_Code] ON [dbo].[SharePackages] ([Code]);
    CREATE INDEX [IX_SharePackages_CreatedById] ON [dbo].[SharePackages] ([CreatedById]);
END
GO

-- 1.14 SharePackageMedia
IF OBJECT_ID(N'[dbo].[SharePackageMedia]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[SharePackageMedia] (
        [SharePackageId] UNIQUEIDENTIFIER NOT NULL,
        [MediaFileId]    UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT [PK_SharePackageMedia] PRIMARY KEY ([SharePackageId], [MediaFileId]),
        CONSTRAINT [FK_SharePackageMedia_SharePackages_SharePackageId] FOREIGN KEY ([SharePackageId])
            REFERENCES [dbo].[SharePackages] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_SharePackageMedia_MediaFiles_MediaFileId] FOREIGN KEY ([MediaFileId])
            REFERENCES [dbo].[MediaFiles] ([Id])
    );

    CREATE INDEX [IX_SharePackageMedia_MediaFileId] ON [dbo].[SharePackageMedia] ([MediaFileId]);
END
GO

-- 1.15 Entitlements
IF OBJECT_ID(N'[dbo].[Entitlements]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Entitlements] (
        [Id]       UNIQUEIDENTIFIER NOT NULL,
        [UserId]   UNIQUEIDENTIFIER NOT NULL,
        [Product]  NVARCHAR(40)     NOT NULL,
        [Source]   NVARCHAR(40)     NOT NULL,
        [StartsAt] DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        [EndsAt]   DATETIME2        NULL,
        CONSTRAINT [PK_Entitlements] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Entitlements_Users_UserId] FOREIGN KEY ([UserId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE CASCADE
    );

    CREATE INDEX [IX_Entitlements_UserId] ON [dbo].[Entitlements] ([UserId]);
END
GO

-- 1.16 MarketPackages (Gói tình huống trên Chợ: Nhà sản xuất & Cộng đồng)
IF OBJECT_ID(N'[dbo].[MarketPackages]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MarketPackages] (
        [Id]            UNIQUEIDENTIFIER NOT NULL,
        [Code]          NVARCHAR(24)     NOT NULL,
        [SellerId]      UNIQUEIDENTIFIER NULL,
        [SellerName]    NVARCHAR(80)     NOT NULL,
        [IsOfficial]    BIT              NOT NULL DEFAULT (0),
        [Title]         NVARCHAR(100)    NOT NULL,
        [Description]   NVARCHAR(500)    NOT NULL,
        [CategoryTag]   NVARCHAR(40)     NOT NULL,
        [PriceVnd]      INT              NOT NULL DEFAULT (0),
        [ComboCount]    INT              NOT NULL DEFAULT (0),
        [ScenarioCount] INT              NOT NULL DEFAULT (0),
        [DownloadCount] INT              NOT NULL DEFAULT (0),
        [RatingAvg]     DECIMAL(3, 2)    NOT NULL DEFAULT (5.00),
        [PayloadJson]   NVARCHAR(MAX)    NOT NULL,
        [IsPublished]   BIT              NOT NULL DEFAULT (1),
        [CreatedAt]     DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_MarketPackages] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_MarketPackages_Users_SellerId] FOREIGN KEY ([SellerId])
            REFERENCES [dbo].[Users] ([Id]) ON DELETE SET NULL
    );

    CREATE UNIQUE INDEX [IX_MarketPackages_Code] ON [dbo].[MarketPackages] ([Code]);
    CREATE INDEX [IX_MarketPackages_IsOfficial_IsPublished] ON [dbo].[MarketPackages] ([IsOfficial], [IsPublished], [CreatedAt] DESC);
END
GO

-- 1.17 MarketPurchases (Lịch sử mua / nhận gói tình huống trên Chợ)
IF OBJECT_ID(N'[dbo].[MarketPurchases]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MarketPurchases] (
        [Id]              UNIQUEIDENTIFIER NOT NULL,
        [MarketPackageId] UNIQUEIDENTIFIER NOT NULL,
        [BuyerId]         UNIQUEIDENTIFIER NOT NULL,
        [PricePaidVnd]    INT              NOT NULL DEFAULT (0),
        [PurchasedAt]     DATETIME2        NOT NULL DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_MarketPurchases] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_MarketPurchases_MarketPackages] FOREIGN KEY ([MarketPackageId])
            REFERENCES [dbo].[MarketPackages] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_MarketPurchases_Users_BuyerId] FOREIGN KEY ([BuyerId])
            REFERENCES [dbo].[Users] ([Id])
    );

    CREATE UNIQUE INDEX [IX_MarketPurchases_Package_Buyer] ON [dbo].[MarketPurchases] ([MarketPackageId], [BuyerId]);
    CREATE INDEX [IX_MarketPurchases_BuyerId] ON [dbo].[MarketPurchases] ([BuyerId]);
END
GO

-- =============================================================================
-- 2. SEED INITIAL CATALOG DATA (AmbientSounds, Ringtones, Aliases, Scenarios)
-- =============================================================================

-- 2.1 Seed AmbientSounds
IF NOT EXISTS (SELECT 1 FROM [dbo].[AmbientSounds] WHERE [OwnerId] IS NULL)
BEGIN
    INSERT INTO [dbo].[AmbientSounds] ([Id], [OwnerId], [Title], [IconName], [MediaFileId], [AssetAudioPath], [LegacyKey], [SortOrder], [CreatedAt])
    VALUES
        (N'car',        NULL, N'Còi xe',              N'car',    NULL, N'audio/backgrounds/traffic.mp3',                  N'traffic',    1, SYSUTCDATETIME()),
        (N'television', NULL, N'Tiếng TV',            N'tv',     NULL, N'audio/ambient/television.wav',           N'television', 2, SYSUTCDATETIME()),
        (N'office',     NULL, N'Văn phòng',           N'office', NULL, N'audio/backgrounds/office.mp3',               N'office',     3, SYSUTCDATETIME()),
        (N'rain',       NULL, N'Trời mưa',            N'rain',   NULL, N'audio/backgrounds/rain.mp3',                 N'rain',       4, SYSUTCDATETIME()),
        (N'dog',        NULL, N'Chó sủa',             N'dog',    NULL, N'audio/backgrounds/dog.mp3',                  NULL,          5, SYSUTCDATETIME()),
        (N'cafe',       NULL, N'Nhạc cà phê',         N'cafe',   NULL, N'audio/ambient/cafe.wav',                 N'cafe',       6, SYSUTCDATETIME()),
        (N'traffic',    NULL, N'Còi xe (giao thông)', N'car',    NULL, N'assets/audio/backgrounds/traffic.mp3',   N'traffic',    7, SYSUTCDATETIME());
END
GO

-- 2.2 Seed Ringtones (đồng bộ mỗi lần chạy để DB cũ cũng nhận chuông MP3 mới)
MERGE [dbo].[Ringtones] AS [target]
USING (VALUES
    (N'iphone',    N'Chuông iPhone',    N'assets/audio/ringtones/iphone.mp3',       1),
    (N'samsung',   N'Chuông Samsung',   N'assets/audio/ringtones/samsung.mp3',      2),
    (N'huawei',    N'Chuông Huawei',    N'assets/audio/ringtones/huawei.mp3',       3),
    (N'zalo',      N'Chuông Zalo',      N'assets/audio/ringtones/zalo.mp3',         4),
    (N'messenger', N'Chuông Messenger', N'assets/audio/ringtones/messenger.mp3',    5),
    (N'classic',   N'Chuông cổ điển',   N'assets/audio/ringtones/classic_ring.wav', 6)
) AS [source] ([Id], [Title], [AssetAudioPath], [SortOrder])
ON [target].[Id] = [source].[Id]
WHEN MATCHED THEN
    UPDATE SET [Title] = [source].[Title],
               [AssetAudioPath] = [source].[AssetAudioPath],
               [SortOrder] = [source].[SortOrder]
WHEN NOT MATCHED BY TARGET THEN
    INSERT ([Id], [Title], [AssetAudioPath], [SortOrder])
    VALUES ([source].[Id], [source].[Title], [source].[AssetAudioPath], [source].[SortOrder])
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;
GO

-- 2.3 Seed ScenarioAliases
IF NOT EXISTS (SELECT 1 FROM [dbo].[ScenarioAliases])
BEGIN
    INSERT INTO [dbo].[ScenarioAliases] ([LegacyId], [ScenarioId], [FallbackTitle], [FallbackCaller], [FallbackDialogue])
    VALUES
        (N'boss',     N'boss-server',     NULL, NULL, NULL),
        (N'mother',   N'mother-urgent',   NULL, NULL, NULL),
        (N'friend',   N'friend-lan-demo', NULL, NULL, NULL),
        (N'delivery', N'delivery',        N'Shipper đang chờ', N'Giao hàng', N'A lô, em có đơn hàng giao cho anh chị. Em đang đứng trước cửa nhà rồi ạ. Anh chị về nhận giúp em nhé, đơn này cần ký nhận trực tiếp ạ.');
END
GO

-- 2.4 Seed Built-in Scenarios & DialogueSteps
IF NOT EXISTS (SELECT 1 FROM [dbo].[Scenarios] WHERE [OwnerId] IS NULL)
BEGIN
    INSERT INTO [dbo].[Scenarios] ([Id], [OwnerId], [Title], [Category], [Source], [CallerName], [Initial], [EstimatedSeconds], [DefaultAmbientSoundId], [IsPro], [CopiedFromScenarioId], [CreatedAt], [UpdatedAt])
    VALUES
        (N'mother-urgent',   NULL, N'Mẹ gọi về gấp',              N'Family',   N'BuiltIn',    N'Mẹ',       N'M', 40, N'television', 0, NULL, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'boss-server',     NULL, N'Sếp báo server sập',         N'Work',     N'BuiltIn',    N'Sếp Hùng', N'S', 55, N'office',     0, NULL, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'landlord-rent',   NULL, N'Chủ trọ đòi tiền nhà',       N'Family',   N'BuiltIn',    N'Chủ trọ',  N'C', 35, N'office',     0, NULL, SYSUTCDATETIME(), SYSUTCDATETIME()),
        (N'friend-lan-demo', NULL, N'Lan (bạn thân) – mẫu tự tạo', N'Personal', N'SampleUser', N'Lan',      N'L', 30, N'cafe',       0, NULL, SYSUTCDATETIME(), SYSUTCDATETIME());

    INSERT INTO [dbo].[DialogueSteps] ([ScenarioId], [Id], [Order], [Type], [Text], [MediaFileId], [AssetAudioPath], [Seconds])
    VALUES
        -- mother-urgent
        (N'mother-urgent', N'm1',  1, N'Speech', N'Alo, con à?',                                             NULL, N'audio/voice/mother_1.wav', 2),
        (N'mother-urgent', N'mw1', 2, N'Wait',   N'Bạn trả lời · chạm để tiếp tục',                          NULL, NULL,                        0),
        (N'mother-urgent', N'm2',  3, N'Speech', N'Ở nhà có việc gấp, con về ngay nhé.',                     NULL, N'audio/voice/mother_2.wav', 4),
        (N'mother-urgent', N'mw2', 4, N'Wait',   N'Bạn trả lời · chạm để tiếp tục',                          NULL, NULL,                        0),
        (N'mother-urgent', N'm3',  5, N'Speech', N'Không được, bố con đang mệt. Về liền đi.',                NULL, N'audio/voice/mother_3.wav', 3),
        (N'mother-urgent', N'm4',  6, N'Speech', N'Nhanh lên nhé con.',                                      NULL, N'audio/voice/mother_4.wav', 2),

        -- boss-server
        (N'boss-server',   N'b1',  1, N'Speech', N'Alo, em nghe máy được không?',                            NULL, N'audio/voice/boss_1.wav',   2),
        (N'boss-server',   N'bw1', 2, N'Wait',   N'Bạn trả lời · chạm để tiếp tục',                          NULL, NULL,                        0),
        (N'boss-server',   N'b2',  3, N'Speech', N'Server bên mình vừa gặp sự cố, cần em kiểm tra ngay.',    NULL, N'audio/voice/boss_2.wav',   4),
        (N'boss-server',   N'b3',  4, N'Speech', N'Em có thể về máy tính trong ít phút nữa không?',          NULL, N'audio/voice/boss_3.wav',   4),
        (N'boss-server',   N'bw2', 5, N'Wait',   N'Bạn trả lời · chạm để tiếp tục',                          NULL, NULL,                        0),
        (N'boss-server',   N'b4',  6, N'Speech', N'Ừ, anh chờ em. Cảm ơn nhé.',                              NULL, N'audio/voice/boss_4.wav',   3),
        (N'boss-server',   N'b5',  7, N'Speech', N'Có gì cập nhật thì gọi lại cho anh.',                     NULL, N'audio/voice/boss_5.wav',   3),

        -- landlord-rent
        (N'landlord-rent', N'l1',  1, N'Speech', N'Alo, cô gọi về tiền phòng tháng này.',                    NULL, N'audio/voice/landlord_1.wav', 3),
        (N'landlord-rent', N'lw1', 2, N'Wait',   N'Bạn trả lời · chạm để tiếp tục',                          NULL, NULL,                          0),
        (N'landlord-rent', N'l2',  3, N'Speech', N'Con thu xếp về gặp cô hôm nay nhé.',                      NULL, N'audio/voice/landlord_2.wav', 3),
        (N'landlord-rent', N'l3',  4, N'Speech', N'Cô cần nói chuyện trực tiếp một chút.',                   NULL, N'audio/voice/landlord_3.wav', 3),
        (N'landlord-rent', N'l4',  5, N'Speech', N'Cô đợi con ở nhà trọ.',                                   NULL, N'audio/voice/landlord_4.wav', 2),

        -- friend-lan-demo
        (N'friend-lan-demo', N'f1',  1, N'Speech', N'Ê, cậu ra ngoài gặp mình một lát được không?',          NULL, N'audio/voice/friend_1.wav', 3),
        (N'friend-lan-demo', N'fw1', 2, N'Wait',   N'Bạn trả lời · chạm để tiếp tục',                        NULL, NULL,                        0),
        (N'friend-lan-demo', N'f2',  3, N'Speech', N'Mình đang có chuyện gấp muốn hỏi cậu.',                 NULL, N'audio/voice/friend_2.wav', 3),
        (N'friend-lan-demo', N'f3',  4, N'Speech', N'Ra chỗ cũ nhé, mình đợi.',                              NULL, N'audio/voice/friend_3.wav', 2);
END
GO

-- 2.5 Seed MarketPackages (Gói tình huống của Nhà sản xuất & Cộng đồng)
IF NOT EXISTS (SELECT 1 FROM [dbo].[MarketPackages])
BEGIN
    INSERT INTO [dbo].[MarketPackages] (
        [Id], [Code], [SellerId], [SellerName], [IsOfficial],
        [Title], [Description], [CategoryTag], [PriceVnd],
        [ComboCount], [ScenarioCount], [DownloadCount], [RatingAvg],
        [PayloadJson], [IsPublished], [CreatedAt]
    )
    VALUES
    (
        'A1111111-1111-4111-8111-111111111111',
        N'MKT-WORK-PRO',
        NULL,
        N'TRỐN Official',
        1,
        N'Gói Thoát Họp & Tăng Ca Khẩn Cấp',
        N'Bộ combo cứu nguy công sở chính hãng: Sếp gọi xử lý sự cố Server gấp và Khách hàng VIP yêu cầu hỗ trợ ngay lập tức.',
        N'Công việc',
        29000,
        2,
        1,
        412,
        4.95,
        N'{"combos":[{"id":"11111111-2222-4333-8444-555555555501","name":"Sếp gọi xử lý Server gấp","scenarioId":"boss-server","callInterface":"zalo","ringtoneType":"interfaceDefault","ringtoneMediaId":null,"backgroundSoundIds":["office"],"customBackgroundMediaId":null,"backgroundVolume":0.3,"backgroundOverridden":false,"createdAt":"2026-10-01T00:00:00Z"},{"id":"11111111-2222-4333-8444-555555555502","name":"Khách VIP báo lỗi hợp đồng","scenarioId":"mkt-vip-client","callInterface":"phone","ringtoneType":"classic","ringtoneMediaId":null,"backgroundSoundIds":["office","cafe"],"customBackgroundMediaId":null,"backgroundVolume":0.3,"backgroundOverridden":false,"createdAt":"2026-10-01T00:00:00Z"}],"customScenarios":[{"id":"mkt-vip-client","title":"Khách VIP báo lỗi hợp đồng","category":"work","source":"user","callerName":"Anh Minh (Đối tác)","initial":"M","estimatedSeconds":35,"defaultBackgroundId":"office","isPro":false,"steps":[{"id":"s1","type":"speech","text":"Alo, bên anh vừa phát hiện sai số liệu trong phụ lục hợp đồng chiều nay.","audioPath":"audio/voice/boss_1.wav","mediaFileId":null,"seconds":4},{"id":"s2","type":"wait","text":"Bạn trả lời · chạm để tiếp tục","audioPath":null,"mediaFileId":null,"seconds":0},{"id":"s3","type":"speech","text":"Em về mở máy kiểm tra và gửi lại bản chỉnh sửa trong 15 phút giúp anh nhé.","audioPath":"audio/voice/boss_2.wav","mediaFileId":null,"seconds":4}]}],"customAmbientSounds":[]}',
        1,
        SYSUTCDATETIME()
    ),
    (
        'A2222222-2222-4222-8222-222222222222',
        N'MKT-PARTY-VIP',
        NULL,
        N'TRỐN Official',
        1,
        N'Gói Giải Cứu Tiệc Rượu & Hẹn Hò',
        N'Dành cho các buổi tiệc kéo dài hoặc cuộc hẹn khó xử: Mẹ gọi về nhà gấp kèm âm nền TV gia đình và Bạn thân nhờ ra đón.',
        N'Tiệc tùng',
        19000,
        2,
        0,
        589,
        4.90,
        N'{"combos":[{"id":"22222222-2222-4333-8444-555555555501","name":"Mẹ gọi về nhà ngay","scenarioId":"mother-urgent","callInterface":"phone","ringtoneType":"classic","ringtoneMediaId":null,"backgroundSoundIds":["television"],"customBackgroundMediaId":null,"backgroundVolume":0.35,"backgroundOverridden":false,"createdAt":"2026-10-02T00:00:00Z"},{"id":"22222222-2222-4333-8444-555555555502","name":"Bạn thân đứng đợi dưới sảnh","scenarioId":"friend-lan-demo","callInterface":"messenger","ringtoneType":"interfaceDefault","ringtoneMediaId":null,"backgroundSoundIds":["car","cafe"],"customBackgroundMediaId":null,"backgroundVolume":0.3,"backgroundOverridden":false,"createdAt":"2026-10-02T00:00:00Z"}],"customScenarios":[],"customAmbientSounds":[]}',
        1,
        SYSUTCDATETIME()
    ),
    (
        'A3333333-3333-4333-8333-333333333333',
        N'MKT-HOME-FREE',
        NULL,
        N'TRỐN Official',
        1,
        N'Gói Chủ Trọ & Shipper Giao Hàng',
        N'Gói miễn phí từ nhà sản xuất: Chủ nhà gọi về kiểm tra phòng và Shipper giao đơn hỏa tốc cần nhận trực tiếp.',
        N'Gia đình',
        0,
        2,
        1,
        830,
        4.85,
        N'{"combos":[{"id":"33333333-2222-4333-8444-555555555501","name":"Chủ nhà báo kiểm tra phòng","scenarioId":"landlord-rent","callInterface":"phone","ringtoneType":"interfaceDefault","ringtoneMediaId":null,"backgroundSoundIds":["rain"],"customBackgroundMediaId":null,"backgroundVolume":0.3,"backgroundOverridden":false,"createdAt":"2026-10-03T00:00:00Z"},{"id":"33333333-2222-4333-8444-555555555502","name":"Shipper giao đơn hỏa tốc","scenarioId":"mkt-shipper-express","callInterface":"zalo","ringtoneType":"interfaceDefault","ringtoneMediaId":null,"backgroundSoundIds":["car"],"customBackgroundMediaId":null,"backgroundVolume":0.3,"backgroundOverridden":false,"createdAt":"2026-10-03T00:00:00Z"}],"customScenarios":[{"id":"mkt-shipper-express","title":"Shipper giao đơn hỏa tốc","category":"personal","source":"user","callerName":"Shipper Giao Hàng","initial":"S","estimatedSeconds":25,"defaultBackgroundId":"car","isPro":false,"steps":[{"id":"sh1","type":"speech","text":"Alo anh chị ơi, em giao đơn hỏa tốc đang đứng trước cổng rồi ạ.","audioPath":"audio/voice/friend_1.wav","mediaFileId":null,"seconds":3},{"id":"sh2","type":"wait","text":"Bạn trả lời · chạm để tiếp tục","audioPath":null,"mediaFileId":null,"seconds":0},{"id":"sh3","type":"speech","text":"Đơn này giá trị cao cần ký nhận trực tiếp, anh chị ra nhận giúp em liền nhé.","audioPath":"audio/voice/friend_2.wav","mediaFileId":null,"seconds":4}]}],"customAmbientSounds":[]}',
        1,
        SYSUTCDATETIME()
    ),
    (
        'A4444444-4444-4444-8444-444444444444',
        N'MKT-COMM-01',
        NULL,
        N'Minh Tuấn (Cộng đồng)',
        0,
        N'Combo Ra Khỏi Cuộc Nhậu Êm Đẹp',
        N'Kịch bản vợ/người yêu gọi về đón gấp kèm tiếng mưa và còi xe cực chân thật do người dùng chia sẻ.',
        N'Cộng đồng',
        15000,
        1,
        1,
        196,
        4.80,
        N'{"combos":[{"id":"44444444-2222-4333-8444-555555555501","name":"Người thương gọi đón gấp","scenarioId":"mkt-partner-pickup","callInterface":"messenger","ringtoneType":"interfaceDefault","ringtoneMediaId":null,"backgroundSoundIds":["rain","car"],"customBackgroundMediaId":null,"backgroundVolume":0.35,"backgroundOverridden":false,"createdAt":"2026-10-04T00:00:00Z"}],"customScenarios":[{"id":"mkt-partner-pickup","title":"Người thương gọi đón gấp","category":"family","source":"user","callerName":"Vợ Yêu","initial":"V","estimatedSeconds":30,"defaultBackgroundId":"rain","isPro":false,"steps":[{"id":"p1","type":"speech","text":"Alo, trời mưa to quá mà xe em lại hết bình, anh qua đón em về ngay được không?","audioPath":"audio/voice/mother_1.wav","mediaFileId":null,"seconds":4},{"id":"p2","type":"wait","text":"Bạn trả lời · chạm để tiếp tục","audioPath":null,"mediaFileId":null,"seconds":0},{"id":"p3","type":"speech","text":"Em đang đứng đợi ở sảnh tòa nhà, anh về liền nhé.","audioPath":"audio/voice/mother_2.wav","mediaFileId":null,"seconds":3}]}],"customAmbientSounds":[]}',
        1,
        SYSUTCDATETIME()
    ),
    (
        'A5555555-5555-4555-8555-555555555555',
        N'MKT-COMM-02',
        NULL,
        N'Hoàng Yến (Cộng đồng)',
        0,
        N'Combo Đội Nhóm Gọi Chạy Deadline',
        N'Dành cho sinh viên và freelancer rút lui lịch sự khi đang ngồi cà phê hoặc tụ tập quá lâu.',
        N'Cộng đồng',
        0,
        1,
        0,
        324,
        4.75,
        N'{"combos":[{"id":"55555555-2222-4333-8444-555555555501","name":"Leader gọi họp nhóm gấp","scenarioId":"boss-server","callInterface":"zalo","ringtoneType":"interfaceDefault","ringtoneMediaId":null,"backgroundSoundIds":["cafe"],"customBackgroundMediaId":null,"backgroundVolume":0.25,"backgroundOverridden":false,"createdAt":"2026-10-05T00:00:00Z"}],"customScenarios":[],"customAmbientSounds":[]}',
        1,
        SYSUTCDATETIME()
    );
END
GO
