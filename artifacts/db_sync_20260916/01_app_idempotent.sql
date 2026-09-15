CREATE TABLE IF NOT EXISTS `__EFMigrationsHistory` (
    `MigrationId` varchar(150) CHARACTER SET utf8mb4 NOT NULL,
    `ProductVersion` varchar(32) CHARACTER SET utf8mb4 NOT NULL,
    CONSTRAINT `PK___EFMigrationsHistory` PRIMARY KEY (`MigrationId`)
) CHARACTER SET=utf8mb4;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    ALTER DATABASE CHARACTER SET utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Addresses` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `Title` longtext CHARACTER SET utf8mb4 NULL,
        `FullName` longtext CHARACTER SET utf8mb4 NULL,
        `Phonenumber` longtext CHARACTER SET utf8mb4 NULL,
        `TaxNumber` longtext CHARACTER SET utf8mb4 NULL,
        `Country` int NOT NULL,
        `Level1` longtext CHARACTER SET utf8mb4 NULL,
        `Level2` longtext CHARACTER SET utf8mb4 NULL,
        `Level3` longtext CHARACTER SET utf8mb4 NULL,
        `Level4` longtext CHARACTER SET utf8mb4 NULL,
        `ZipPostalCode` longtext CHARACTER SET utf8mb4 NULL,
        `FullAddress` longtext CHARACTER SET utf8mb4 NULL,
        `Apartment` longtext CHARACTER SET utf8mb4 NULL,
        `Lng` decimal(65,30) NULL,
        `Lat` decimal(65,30) NULL,
        `IsCompany` tinyint(1) NOT NULL,
        `AddressType` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Addresses` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetRoles` (
        `Id` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `Name` varchar(256) CHARACTER SET utf8mb4 NULL,
        `NormalizedName` varchar(256) CHARACTER SET utf8mb4 NULL,
        `ConcurrencyStamp` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_AspNetRoles` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetUsers` (
        `Id` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `FirstName` longtext CHARACTER SET utf8mb4 NULL,
        `LastName` longtext CHARACTER SET utf8mb4 NULL,
        `FullName` longtext CHARACTER SET utf8mb4 NULL,
        `Corporate` longtext CHARACTER SET utf8mb4 NULL,
        `Position` longtext CHARACTER SET utf8mb4 NULL,
        `Gender` int NULL,
        `Birthday` datetime(6) NULL,
        `Interests` longtext CHARACTER SET utf8mb4 NULL,
        `Education` longtext CHARACTER SET utf8mb4 NULL,
        `Address` longtext CHARACTER SET utf8mb4 NULL,
        `Facebook` longtext CHARACTER SET utf8mb4 NULL,
        `Twitter` longtext CHARACTER SET utf8mb4 NULL,
        `Instagram` longtext CHARACTER SET utf8mb4 NULL,
        `LinkedIn` longtext CHARACTER SET utf8mb4 NULL,
        `Skype` longtext CHARACTER SET utf8mb4 NULL,
        `WhatsApp` longtext CHARACTER SET utf8mb4 NULL,
        `LastLoginDate` datetime(6) NULL,
        `LastConfirmEmail` datetime(6) NULL,
        `ProfilePhoto` longtext CHARACTER SET utf8mb4 NULL,
        `DeviceId` longtext CHARACTER SET utf8mb4 NULL,
        `Lang` longtext CHARACTER SET utf8mb4 NULL,
        `CountryPhoneCode` longtext CHARACTER SET utf8mb4 NULL,
        `ExternalUserId` longtext CHARACTER SET utf8mb4 NULL,
        `ExternalTokenResponse` longtext CHARACTER SET utf8mb4 NULL,
        `IsActive` tinyint(1) NOT NULL,
        `Topics` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UserName` varchar(256) CHARACTER SET utf8mb4 NULL,
        `NormalizedUserName` varchar(256) CHARACTER SET utf8mb4 NULL,
        `Email` varchar(256) CHARACTER SET utf8mb4 NULL,
        `NormalizedEmail` varchar(256) CHARACTER SET utf8mb4 NULL,
        `EmailConfirmed` tinyint(1) NOT NULL,
        `PasswordHash` longtext CHARACTER SET utf8mb4 NULL,
        `SecurityStamp` longtext CHARACTER SET utf8mb4 NULL,
        `ConcurrencyStamp` longtext CHARACTER SET utf8mb4 NULL,
        `PhoneNumber` longtext CHARACTER SET utf8mb4 NULL,
        `PhoneNumberConfirmed` tinyint(1) NOT NULL,
        `TwoFactorEnabled` tinyint(1) NOT NULL,
        `LockoutEnd` datetime(6) NULL,
        `LockoutEnabled` tinyint(1) NOT NULL,
        `AccessFailedCount` int NOT NULL,
        CONSTRAINT `PK_AspNetUsers` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Banners` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `TitleEn` longtext CHARACTER SET utf8mb4 NULL,
        `TitleAr` longtext CHARACTER SET utf8mb4 NULL,
        `TitleTr` longtext CHARACTER SET utf8mb4 NULL,
        `DescriptionEn` longtext CHARACTER SET utf8mb4 NULL,
        `DescriptionAr` longtext CHARACTER SET utf8mb4 NULL,
        `DescriptionTr` longtext CHARACTER SET utf8mb4 NULL,
        `Url` longtext CHARACTER SET utf8mb4 NULL,
        `Active` tinyint(1) NOT NULL,
        `FeaturedImage` longtext CHARACTER SET utf8mb4 NULL,
        `BannerLocation` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Banners` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Cities` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` longtext CHARACTER SET utf8mb4 NULL,
        `Country` int NOT NULL,
        `GeoNameId` int NULL,
        CONSTRAINT `PK_Cities` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Faqs` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `QuestionAr` longtext CHARACTER SET utf8mb4 NULL,
        `QuestionEn` longtext CHARACTER SET utf8mb4 NULL,
        `QuestionTr` longtext CHARACTER SET utf8mb4 NULL,
        `AnswerAr` longtext CHARACTER SET utf8mb4 NULL,
        `AnswerEn` longtext CHARACTER SET utf8mb4 NULL,
        `AnswerTr` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Faqs` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `FavoriteProducts` (
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ProductId` int NOT NULL,
        `ProductTitle` longtext CHARACTER SET utf8mb4 NULL,
        `ProductImage` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_FavoriteProducts` PRIMARY KEY (`UserId`, `ProductId`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Notifications` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `TitleAr` longtext CHARACTER SET utf8mb4 NULL,
        `TitleEn` longtext CHARACTER SET utf8mb4 NULL,
        `TitleTr` longtext CHARACTER SET utf8mb4 NULL,
        `TextAr` longtext CHARACTER SET utf8mb4 NULL,
        `TextEn` longtext CHARACTER SET utf8mb4 NULL,
        `TextTr` longtext CHARACTER SET utf8mb4 NULL,
        `Image` longtext CHARACTER SET utf8mb4 NULL,
        `Url` longtext CHARACTER SET utf8mb4 NULL,
        `Topic` longtext CHARACTER SET utf8mb4 NULL,
        `NotificationType` int NOT NULL,
        `EntityData` longtext CHARACTER SET utf8mb4 NULL,
        `NotLoggedInRecivedCount` int NOT NULL,
        `NotLoggedInReadCount` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Notifications` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `OpenIddictApplications` (
        `Id` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ClientId` varchar(100) CHARACTER SET utf8mb4 NULL,
        `ClientSecret` longtext CHARACTER SET utf8mb4 NULL,
        `ConcurrencyToken` varchar(50) CHARACTER SET utf8mb4 NULL,
        `ConsentType` varchar(50) CHARACTER SET utf8mb4 NULL,
        `DisplayName` longtext CHARACTER SET utf8mb4 NULL,
        `DisplayNames` longtext CHARACTER SET utf8mb4 NULL,
        `Permissions` longtext CHARACTER SET utf8mb4 NULL,
        `PostLogoutRedirectUris` longtext CHARACTER SET utf8mb4 NULL,
        `Properties` longtext CHARACTER SET utf8mb4 NULL,
        `RedirectUris` longtext CHARACTER SET utf8mb4 NULL,
        `Requirements` longtext CHARACTER SET utf8mb4 NULL,
        `Type` varchar(50) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_OpenIddictApplications` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `OpenIddictScopes` (
        `Id` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ConcurrencyToken` varchar(50) CHARACTER SET utf8mb4 NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `Descriptions` longtext CHARACTER SET utf8mb4 NULL,
        `DisplayName` longtext CHARACTER SET utf8mb4 NULL,
        `DisplayNames` longtext CHARACTER SET utf8mb4 NULL,
        `Name` varchar(200) CHARACTER SET utf8mb4 NULL,
        `Properties` longtext CHARACTER SET utf8mb4 NULL,
        `Resources` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_OpenIddictScopes` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `ProductReviews` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ReviewerId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ProductId` int NOT NULL,
        `ProductTitle` longtext CHARACTER SET utf8mb4 NULL,
        `ProductImage` longtext CHARACTER SET utf8mb4 NULL,
        `Rate` int NOT NULL,
        `TextReview` longtext CHARACTER SET utf8mb4 NULL,
        `ImageReview` longtext CHARACTER SET utf8mb4 NULL,
        `IsApproved` tinyint(1) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_ProductReviews` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Settings` PRIMARY KEY (`Key`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `Testimonials` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Testimonials` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetRoleClaims` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `RoleId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ClaimType` longtext CHARACTER SET utf8mb4 NULL,
        `ClaimValue` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_AspNetRoleClaims` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_AspNetRoleClaims_AspNetRoles_RoleId` FOREIGN KEY (`RoleId`) REFERENCES `AspNetRoles` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `RolePermission` (
        `AppRoleId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `SolPermissionKey` tinyint unsigned NOT NULL,
        CONSTRAINT `PK_RolePermission` PRIMARY KEY (`AppRoleId`, `SolPermissionKey`),
        CONSTRAINT `FK_RolePermission_AspNetRoles_AppRoleId` FOREIGN KEY (`AppRoleId`) REFERENCES `AspNetRoles` (`Id`) ON DELETE RESTRICT
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetUserClaims` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ClaimType` longtext CHARACTER SET utf8mb4 NULL,
        `ClaimValue` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_AspNetUserClaims` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_AspNetUserClaims_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetUserLogins` (
        `LoginProvider` varchar(300) CHARACTER SET utf8mb4 NOT NULL,
        `ProviderKey` varchar(300) CHARACTER SET utf8mb4 NOT NULL,
        `ProviderDisplayName` longtext CHARACTER SET utf8mb4 NULL,
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        CONSTRAINT `PK_AspNetUserLogins` PRIMARY KEY (`LoginProvider`, `ProviderKey`),
        CONSTRAINT `FK_AspNetUserLogins_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetUserRoles` (
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `RoleId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        CONSTRAINT `PK_AspNetUserRoles` PRIMARY KEY (`UserId`, `RoleId`),
        CONSTRAINT `FK_AspNetUserRoles_AspNetRoles_RoleId` FOREIGN KEY (`RoleId`) REFERENCES `AspNetRoles` (`Id`) ON DELETE CASCADE,
        CONSTRAINT `FK_AspNetUserRoles_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `AspNetUserTokens` (
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `LoginProvider` varchar(300) CHARACTER SET utf8mb4 NOT NULL,
        `Name` varchar(300) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_AspNetUserTokens` PRIMARY KEY (`UserId`, `LoginProvider`, `Name`),
        CONSTRAINT `FK_AspNetUserTokens_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `SmsLogs` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `Code` longtext CHARACTER SET utf8mb4 NULL,
        `Text` longtext CHARACTER SET utf8mb4 NULL,
        `Response` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_SmsLogs` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_SmsLogs_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE RESTRICT
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `NotificationMessage` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `RecivedDate` datetime(6) NULL,
        `ReadDate` datetime(6) NULL,
        `UserId` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `NotificationId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_NotificationMessage` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_NotificationMessage_AspNetUsers_UserId` FOREIGN KEY (`UserId`) REFERENCES `AspNetUsers` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_NotificationMessage_Notifications_NotificationId` FOREIGN KEY (`NotificationId`) REFERENCES `Notifications` (`Id`) ON DELETE RESTRICT
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `OpenIddictAuthorizations` (
        `Id` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ApplicationId` varchar(36) CHARACTER SET utf8mb4 NULL,
        `ConcurrencyToken` varchar(50) CHARACTER SET utf8mb4 NULL,
        `CreationDate` datetime(6) NULL,
        `Properties` longtext CHARACTER SET utf8mb4 NULL,
        `Scopes` longtext CHARACTER SET utf8mb4 NULL,
        `Status` varchar(50) CHARACTER SET utf8mb4 NULL,
        `Subject` varchar(400) CHARACTER SET utf8mb4 NULL,
        `Type` varchar(50) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_OpenIddictAuthorizations` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_OpenIddictAuthorizations_OpenIddictApplications_ApplicationId` FOREIGN KEY (`ApplicationId`) REFERENCES `OpenIddictApplications` (`Id`) ON DELETE RESTRICT
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `TestimonialTranslation` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Name` longtext CHARACTER SET utf8mb4 NULL,
        `Photo` longtext CHARACTER SET utf8mb4 NULL,
        `Text` longtext CHARACTER SET utf8mb4 NULL,
        `CoreId` int NOT NULL,
        `Language` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_TestimonialTranslation` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_TestimonialTranslation_Testimonials_CoreId` FOREIGN KEY (`CoreId`) REFERENCES `Testimonials` (`Id`) ON DELETE CASCADE
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE TABLE `OpenIddictTokens` (
        `Id` varchar(36) CHARACTER SET utf8mb4 NOT NULL,
        `ApplicationId` varchar(36) CHARACTER SET utf8mb4 NULL,
        `AuthorizationId` varchar(36) CHARACTER SET utf8mb4 NULL,
        `ConcurrencyToken` varchar(50) CHARACTER SET utf8mb4 NULL,
        `CreationDate` datetime(6) NULL,
        `ExpirationDate` datetime(6) NULL,
        `Payload` longtext CHARACTER SET utf8mb4 NULL,
        `Properties` longtext CHARACTER SET utf8mb4 NULL,
        `RedemptionDate` datetime(6) NULL,
        `ReferenceId` varchar(100) CHARACTER SET utf8mb4 NULL,
        `Status` varchar(50) CHARACTER SET utf8mb4 NULL,
        `Subject` varchar(400) CHARACTER SET utf8mb4 NULL,
        `Type` varchar(50) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_OpenIddictTokens` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_OpenIddictTokens_OpenIddictApplications_ApplicationId` FOREIGN KEY (`ApplicationId`) REFERENCES `OpenIddictApplications` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_OpenIddictTokens_OpenIddictAuthorizations_AuthorizationId` FOREIGN KEY (`AuthorizationId`) REFERENCES `OpenIddictAuthorizations` (`Id`) ON DELETE RESTRICT
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_AspNetRoleClaims_RoleId` ON `AspNetRoleClaims` (`RoleId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE UNIQUE INDEX `RoleNameIndex` ON `AspNetRoles` (`NormalizedName`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_AspNetUserClaims_UserId` ON `AspNetUserClaims` (`UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_AspNetUserLogins_UserId` ON `AspNetUserLogins` (`UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_AspNetUserRoles_RoleId` ON `AspNetUserRoles` (`RoleId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `EmailIndex` ON `AspNetUsers` (`NormalizedEmail`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE UNIQUE INDEX `UserNameIndex` ON `AspNetUsers` (`NormalizedUserName`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_NotificationMessage_NotificationId` ON `NotificationMessage` (`NotificationId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_NotificationMessage_UserId` ON `NotificationMessage` (`UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE UNIQUE INDEX `IX_OpenIddictApplications_ClientId` ON `OpenIddictApplications` (`ClientId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_OpenIddictAuthorizations_ApplicationId_Status_Subject_Type` ON `OpenIddictAuthorizations` (`ApplicationId`, `Status`, `Subject`, `Type`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE UNIQUE INDEX `IX_OpenIddictScopes_Name` ON `OpenIddictScopes` (`Name`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_OpenIddictTokens_ApplicationId_Status_Subject_Type` ON `OpenIddictTokens` (`ApplicationId`, `Status`, `Subject`, `Type`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_OpenIddictTokens_AuthorizationId` ON `OpenIddictTokens` (`AuthorizationId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE UNIQUE INDEX `IX_OpenIddictTokens_ReferenceId` ON `OpenIddictTokens` (`ReferenceId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_SmsLogs_UserId` ON `SmsLogs` (`UserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    CREATE INDEX `IX_TestimonialTranslation_CoreId` ON `TestimonialTranslation` (`CoreId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114132548_AppInit') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220114132548_AppInit', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` DROP COLUMN `DescriptionAr`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` DROP COLUMN `DescriptionEn`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` DROP COLUMN `DescriptionTr`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` DROP COLUMN `TitleAr`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` RENAME COLUMN `TitleTr` TO `Title`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` RENAME COLUMN `TitleEn` TO `Description`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    ALTER TABLE `Banners` ADD `Order` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120122434_addedBanners') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220120122434_addedBanners', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Address`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Corporate`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Education`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Facebook`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Instagram`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Interests`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `LinkedIn`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Position`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Skype`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `Twitter`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    ALTER TABLE `AspNetUsers` DROP COLUMN `WhatsApp`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123111100_removedUnusedPropertiesFromAppUser') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220123111100_removedUnusedPropertiesFromAppUser', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220421073652_addedUserDefaultLocation') THEN

    ALTER TABLE `AspNetUsers` ADD `DefaultLat` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220421073652_addedUserDefaultLocation') THEN

    ALTER TABLE `AspNetUsers` ADD `DefaultLng` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220421073652_addedUserDefaultLocation') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220421073652_addedUserDefaultLocation', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915150000_AddSupportMessages') THEN

    CREATE TABLE `SupportMessages` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` varchar(36) CHARACTER SET utf8mb4 NULL,
        `SenderName` varchar(150) CHARACTER SET utf8mb4 NULL,
        `SenderPhone` varchar(50) CHARACTER SET utf8mb4 NULL,
        `SenderEmail` varchar(150) CHARACTER SET utf8mb4 NULL,
        `Title` varchar(200) CHARACTER SET utf8mb4 NULL,
        `Message` longtext CHARACTER SET utf8mb4 NULL,
        `Status` int NOT NULL,
        `AdminNotes` longtext CHARACTER SET utf8mb4 NULL,
        `ResolvedDate` datetime(6) NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_SupportMessages` PRIMARY KEY (`Id`)
    ) CHARACTER SET=utf8mb4;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915150000_AddSupportMessages') THEN

    CREATE INDEX `IX_SupportMessages_Status_CreatedDate` ON `SupportMessages` (`Status`, `CreatedDate`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915150000_AddSupportMessages') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915150000_AddSupportMessages', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

