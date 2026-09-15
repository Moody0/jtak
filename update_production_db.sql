-- ==============================================================================
-- JTAK PRODUCTION DATABASE MIGRATION SCRIPT (100% IDEMPOTENT & EF CORE COMPLIANT)
-- Generated: 2026-09-13
-- Target: MySQL 8.0+ / MariaDB
-- Architecture: 5 Micro-DbContexts (App, Catalog, Orders, Accounting, Shipping)
-- ==============================================================================
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS `__EFMigrationsHistory` (
    `MigrationId` varchar(150) CHARACTER SET utf8mb4 NOT NULL,
    `ProductVersion` varchar(32) CHARACTER SET utf8mb4 NOT NULL,
    CONSTRAINT `PK___EFMigrationsHistory` PRIMARY KEY (`MigrationId`)
) CHARACTER SET=utf8mb4;


-- ------------------------------------------------------------------------------
-- SECTION: APP & IDENTITY
-- ------------------------------------------------------------------------------
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

-- ------------------------------------------------------------------------------
-- SECTION: CATALOG & DARK STORE
-- ------------------------------------------------------------------------------
START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Merchant` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` varchar(128) CHARACTER SET utf8mb4 NOT NULL,
        `ShortDescription` varchar(128) CHARACTER SET utf8mb4 NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `Facebook` longtext CHARACTER SET utf8mb4 NULL,
        `Instagram` longtext CHARACTER SET utf8mb4 NULL,
        `Twitter` longtext CHARACTER SET utf8mb4 NULL,
        `Website` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN1Title` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN1` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN2Title` longtext CHARACTER SET utf8mb4 NULL,
        `IBAN2` longtext CHARACTER SET utf8mb4 NULL,
        `Paypal` longtext CHARACTER SET utf8mb4 NULL,
        `Phone1` longtext CHARACTER SET utf8mb4 NULL,
        `Phone2` longtext CHARACTER SET utf8mb4 NULL,
        `Address` longtext CHARACTER SET utf8mb4 NULL,
        `ShippingCost` decimal(65,30) NOT NULL,
        `MinOrder` decimal(65,30) NOT NULL,
        `Active` tinyint(1) NOT NULL,
        `DefaultCurrency` int NOT NULL,
        `OwnerId` char(36) COLLATE ascii_general_ci NOT NULL,
        `Photo` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Merchant` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Settings` PRIMARY KEY (`Key`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Tags` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `NameAr` longtext CHARACTER SET utf8mb4 NULL,
        `NameEn` longtext CHARACTER SET utf8mb4 NULL,
        `NameTr` longtext CHARACTER SET utf8mb4 NULL,
        `Photo` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Tags` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_ProductCategories` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` varchar(128) CHARACTER SET utf8mb4 NULL,
        `Icon` longtext CHARACTER SET utf8mb4 NULL,
        `MerchantId` int NULL,
        `Active` tinyint(1) NOT NULL,
        `ParentId` int NULL,
        `SubCategoriesCsv` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_ProductCategories` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_ProductCategories_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_ProductCategories_Catalog_ProductCategories_ParentId` FOREIGN KEY (`ParentId`) REFERENCES `Catalog_ProductCategories` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_Products` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Title` varchar(128) CHARACTER SET utf8mb4 NOT NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `Photos` longtext CHARACTER SET utf8mb4 NULL,
        `TotalCount` int NOT NULL,
        `SoldCount` int NOT NULL,
        `Unit` longtext CHARACTER SET utf8mb4 NULL,
        `Price` decimal(65,30) NOT NULL,
        `Discount` decimal(65,30) NOT NULL,
        `Currency` int NOT NULL,
        `Active` tinyint(1) NOT NULL,
        `ExpiryDate` datetime(6) NULL,
        `IsFeatured` tinyint(1) NOT NULL,
        `Rate` double NOT NULL,
        `RateCount` int NOT NULL,
        `MerchantId` int NOT NULL,
        `ProductCategoryId` int NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_Products` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_Products_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_Products_Catalog_ProductCategories_ProductCategoryId` FOREIGN KEY (`ProductCategoryId`) REFERENCES `Catalog_ProductCategories` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `DynamicField` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ProductCategoryId` int NOT NULL,
        `DisplayName` longtext CHARACTER SET utf8mb4 NULL,
        `ControlType` tinyint unsigned NOT NULL,
        `IsRequired` tinyint(1) NOT NULL,
        `DisplayOrder` int NOT NULL,
        `PotentialValues` longtext CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_DynamicField` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_DynamicField_Catalog_ProductCategories_ProductCategoryId` FOREIGN KEY (`ProductCategoryId`) REFERENCES `Catalog_ProductCategories` (`Id`) ON DELETE CASCADE
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `Catalog_ProductTags` (
        `ProductId` int NOT NULL,
        `TagId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_ProductTags` PRIMARY KEY (`ProductId`, `TagId`),
        CONSTRAINT `FK_Catalog_ProductTags_Catalog_Products_ProductId` FOREIGN KEY (`ProductId`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_ProductTags_Catalog_Tags_TagId` FOREIGN KEY (`TagId`) REFERENCES `Catalog_Tags` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE TABLE `DynamicFieldValue` (
        `DynamicFieldId` int NOT NULL,
        `ProductId` bigint NOT NULL,
        `ProductId1` int NULL,
        `ControlType` tinyint unsigned NOT NULL,
        `StringVal` varchar(255) CHARACTER SET utf8mb4 NULL,
        `NumberVal` decimal(65,30) NULL,
        `DateTimeVal` datetime(6) NULL,
        `BoolVal` tinyint(1) NULL,
        CONSTRAINT `PK_DynamicFieldValue` PRIMARY KEY (`DynamicFieldId`, `ProductId`),
        CONSTRAINT `FK_DynamicFieldValue_Catalog_Products_ProductId1` FOREIGN KEY (`ProductId1`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_DynamicFieldValue_DynamicField_DynamicFieldId` FOREIGN KEY (`DynamicFieldId`) REFERENCES `DynamicField` (`Id`) ON DELETE CASCADE
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_ProductCategories_MerchantId` ON `Catalog_ProductCategories` (`MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_ProductCategories_ParentId` ON `Catalog_ProductCategories` (`ParentId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_Products_MerchantId` ON `Catalog_Products` (`MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_Products_ProductCategoryId` ON `Catalog_Products` (`ProductCategoryId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_Catalog_ProductTags_TagId` ON `Catalog_ProductTags` (`TagId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_DynamicField_ProductCategoryId` ON `DynamicField` (`ProductCategoryId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    CREATE INDEX `IX_DynamicFieldValue_ProductId1` ON `DynamicFieldValue` (`ProductId1`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135506_CatalogInit') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220114135506_CatalogInit', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_ProductCategories` DROP FOREIGN KEY `FK_Catalog_ProductCategories_Catalog_Merchant_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Products` DROP FOREIGN KEY `FK_Catalog_Products_Catalog_Merchant_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Products` DROP INDEX `IX_Catalog_Products_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_ProductCategories` DROP INDEX `IX_Catalog_ProductCategories_MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_ProductCategories` DROP COLUMN `MerchantId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Merchant` ADD `Lat` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Merchant` ADD `Lng` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    ALTER TABLE `Catalog_Merchant` ADD `ShipingCoverageInMeters` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    CREATE TABLE `Catalog_MerchantProduct` (
        `MerchantId` int NOT NULL,
        `ProductId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_MerchantProduct` PRIMARY KEY (`MerchantId`, `ProductId`),
        CONSTRAINT `FK_Catalog_MerchantProduct_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_MerchantProduct_Catalog_Products_ProductId` FOREIGN KEY (`ProductId`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    CREATE INDEX `IX_Catalog_MerchantProduct_ProductId` ON `Catalog_MerchantProduct` (`ProductId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220120133627_addedMoreMerchantStuff') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220120133627_addedMoreMerchantStuff', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `Discount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `Price`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `SoldCount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_Products` DROP COLUMN `TotalCount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_ProductCategories` ADD `Order` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `AdditionalPercent` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `Cost` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `Discount` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    CREATE INDEX `IX_Catalog_Merchant_Lat` ON `Catalog_Merchant` (`Lat`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    CREATE INDEX `IX_Catalog_Merchant_Lng` ON `Catalog_Merchant` (`Lng`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122141300_addedMoreMerchantProductDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220122141300_addedMoreMerchantProductDetails', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122142155_addedProductCategoryOrderIndex') THEN

    CREATE INDEX `IX_Catalog_ProductCategories_Order` ON `Catalog_ProductCategories` (`Order`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220122142155_addedProductCategoryOrderIndex') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220122142155_addedProductCategoryOrderIndex', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220125115448_fixedTypo') THEN

    ALTER TABLE `Catalog_Merchant` RENAME COLUMN `ShipingCoverageInMeters` TO `ShippingCoverageInMeters`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220125115448_fixedTypo') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220125115448_fixedTypo', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220129103311_madeMerchantLocationRequired') THEN

    ALTER TABLE `Catalog_Merchant` MODIFY COLUMN `Lng` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220129103311_madeMerchantLocationRequired') THEN

    ALTER TABLE `Catalog_Merchant` MODIFY COLUMN `Lat` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220129103311_madeMerchantLocationRequired') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220129103311_madeMerchantLocationRequired', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    ALTER TABLE `Catalog_MerchantProduct` RENAME COLUMN `Cost` TO `ProfitOutOfMerchantPricePercent`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    ALTER TABLE `Catalog_MerchantProduct` RENAME COLUMN `AdditionalPercent` TO `MerchantPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    ALTER TABLE `Catalog_MerchantProduct` ADD `AdditionalProfitPercent` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094220_updatedMerchantProductPrice') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203094220_updatedMerchantProductPrice', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Facebook`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `IBAN2`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `IBAN2Title`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Instagram`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `MinOrder`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Paypal`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `ShippingCost`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Twitter`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` DROP COLUMN `Website`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220314101509_optimizedMerchant') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220314101509_optimizedMerchant', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220319100351_improvedMerchant') THEN

    ALTER TABLE `Catalog_Merchant` ADD `ProfitOutOfMerchantPricePercent` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220319100351_improvedMerchant') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220319100351_improvedMerchant', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260910113000_addMerchantKind') THEN

    ALTER TABLE `Catalog_Merchant` ADD `MerchantKind` tinyint unsigned NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260910113000_addMerchantKind') THEN


                    UPDATE Catalog_Merchant
                    SET MerchantKind = CASE
                        WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                             REGEXP 'صيدلي|pharmacy|drugstore' THEN 2
                        WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                             REGEXP 'سوبرماركت|سوبر ماركت|بقالة|تموينات|hypermarket|grocery|market|mart' THEN 1
                        WHEN LOWER(CONCAT(COALESCE(Title, ''), ' ', COALESCE(ShortDescription, '')))
                             REGEXP 'متجر|مول|shop|store|mall|cosmetic|تجميل' THEN 3
                        ELSE 0
                    END;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260910113000_addMerchantKind') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260910113000_addMerchantKind', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE TABLE `Catalog_ProductBatches` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ProductId` int NOT NULL,
        `MerchantId` int NOT NULL,
        `BatchNumber` varchar(64) CHARACTER SET utf8mb4 NOT NULL,
        `LotNumber` varchar(64) CHARACTER SET utf8mb4 NULL,
        `Barcode` varchar(64) CHARACTER SET utf8mb4 NOT NULL,
        `Sku` varchar(64) CHARACTER SET utf8mb4 NULL,
        `LocationBin` varchar(128) CHARACTER SET utf8mb4 NULL,
        `ManufactureDate` datetime(6) NULL,
        `ExpirationDate` datetime(6) NOT NULL,
        `QuantityOnHand` int NOT NULL,
        `QuantityReserved` int NOT NULL,
        `CostPrice` decimal(18,2) NOT NULL,
        `SellingPrice` decimal(18,2) NULL,
        `Status` int NOT NULL,
        `Notes` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `DeletionDate` datetime(6) NULL,
        `DeletedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_ProductBatches` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_ProductBatches_Catalog_Merchant_MerchantId` FOREIGN KEY (`MerchantId`) REFERENCES `Catalog_Merchant` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Catalog_ProductBatches_Catalog_Products_ProductId` FOREIGN KEY (`ProductId`) REFERENCES `Catalog_Products` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE TABLE `Catalog_BatchReservations` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ProductBatchId` int NOT NULL,
        `OrderId` int NOT NULL,
        `OrderDetailId` int NOT NULL,
        `Quantity` int NOT NULL,
        `IsDeducted` tinyint(1) NOT NULL,
        `DeductedDate` datetime(6) NULL,
        `IsReleased` tinyint(1) NOT NULL,
        `ReleasedDate` datetime(6) NULL,
        `ReleaseReason` varchar(256) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Catalog_BatchReservations` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Catalog_BatchReservations_Catalog_ProductBatches_ProductBatch` FOREIGN KEY (`ProductBatchId`) REFERENCES `Catalog_ProductBatches` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_Barcode` ON `Catalog_ProductBatches` (`Barcode`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_BatchNumber` ON `Catalog_ProductBatches` (`BatchNumber`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_ExpirationDate` ON `Catalog_ProductBatches` (`ExpirationDate`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_MerchantId` ON `Catalog_ProductBatches` (`MerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_ProductBatches_ProductId` ON `Catalog_ProductBatches` (`ProductId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_BatchReservations_OrderDetailId` ON `Catalog_BatchReservations` (`OrderDetailId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_BatchReservations_OrderId` ON `Catalog_BatchReservations` (`OrderId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    CREATE INDEX `IX_Catalog_BatchReservations_ProductBatchId` ON `Catalog_BatchReservations` (`ProductBatchId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911160000_AddProductBatchesAndReservations') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911160000_AddProductBatchesAndReservations', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

-- ------------------------------------------------------------------------------
-- SECTION: ORDERS & DISPATCH
-- ------------------------------------------------------------------------------
START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE TABLE `Orders_Orders` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `UserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `User` longtext CHARACTER SET utf8mb4 NULL,
        `PurchaseDate` datetime(6) NULL,
        `Description` longtext CHARACTER SET utf8mb4 NULL,
        `PaymentMethod` int NOT NULL,
        `PaymentDescription` longtext CHARACTER SET utf8mb4 NULL,
        `Notes` longtext CHARACTER SET utf8mb4 NULL,
        `Address` longtext CHARACTER SET utf8mb4 NULL,
        `Phonenumber` longtext CHARACTER SET utf8mb4 NULL,
        `OrderStatus` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_Orders` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE TABLE `Orders_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_Settings` PRIMARY KEY (`Key`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE TABLE `Orders_OrderDetails` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Quantity` int NOT NULL,
        `SinglePrice` decimal(65,30) NOT NULL,
        `SingleDiscount` decimal(65,30) NOT NULL,
        `TotalPrice` decimal(65,30) NOT NULL,
        `TotalDiscount` decimal(65,30) NOT NULL,
        `Currency` int NOT NULL,
        `OrderDetailStatus` int NOT NULL,
        `Warning` longtext CHARACTER SET utf8mb4 NULL,
        `ProductId` int NOT NULL,
        `Product` longtext CHARACTER SET utf8mb4 NULL,
        `OrderId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_OrderDetails` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Orders_OrderDetails_Orders_Orders_OrderId` FOREIGN KEY (`OrderId`) REFERENCES `Orders_Orders` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    CREATE INDEX `IX_Orders_OrderDetails_OrderId` ON `Orders_OrderDetails` (`OrderId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220114135533_OrdersInit') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220114135533_OrdersInit', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` RENAME COLUMN `Product` TO `ProductTitle`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_Orders` ADD `Lat` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_Orders` ADD `Lng` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `ProductImage` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220123105341_improvedOrderAndOrderDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220123105341_improvedOrderAndOrderDetails', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` RENAME COLUMN `SingleDiscount` TO `SingleFinalPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `MerchantId` int NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `MerchantTitle` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `ProductUnit` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    CREATE TABLE `Orders_OrderStatusChangeLogs` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `OrderId` int NOT NULL,
        `OrderDetailId` int NOT NULL,
        `OrderDetailStatus` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Orders_OrderStatusChangeLogs` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220126133742_addedOrdersUpdates') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220126133742_addedOrdersUpdates', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` DROP COLUMN `OrderDetailId`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` MODIFY COLUMN `Id` char(36) COLLATE ascii_general_ci NOT NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` ADD `DriverId` char(36) COLLATE ascii_general_ci NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` ADD `OrdreDetails` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryId` char(36) COLLATE ascii_general_ci NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    CREATE INDEX `IX_Orders_OrderStatusChangeLogs_OrderId` ON `Orders_OrderStatusChangeLogs` (`OrderId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    ALTER TABLE `Orders_OrderStatusChangeLogs` ADD CONSTRAINT `FK_Orders_OrderStatusChangeLogs_Orders_Orders_OrderId` FOREIGN KEY (`OrderId`) REFERENCES `Orders_Orders` (`Id`) ON DELETE RESTRICT;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220128211103_addedOrderUpdateLogAndDeliveryId') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220128211103_addedOrderUpdateLogAndDeliveryId', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094159_removedRedundantPriceing') THEN

    ALTER TABLE `Orders_OrderDetails` DROP COLUMN `TotalDiscount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094159_removedRedundantPriceing') THEN

    ALTER TABLE `Orders_OrderDetails` DROP COLUMN `TotalPrice`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203094159_removedRedundantPriceing') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203094159_removedRedundantPriceing', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203114313_addedMoreOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `SingleAdditionalProfit` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203114313_addedMoreOrderDetails') THEN

    ALTER TABLE `Orders_OrderDetails` ADD `SingleMerchantProfit` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203114313_addedMoreOrderDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203114313_addedMoreOrderDetails', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220403142048_addedDerliveryUserName') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryUser` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220403142048_addedDerliveryUserName') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220403142048_addedDerliveryUserName', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryLat` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryLng` decimal(65,30) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryLocationUpdatedAt` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260909150000_addDeliveryLiveLocation') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260909150000_addDeliveryLiveLocation', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryOtp` varchar(16) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveredAt` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `ProofOfDeliverySignature` longtext NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `ProofOfDeliveryPhotoUrl` longtext NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    ALTER TABLE `Orders_Orders` ADD `DeliveryNotes` longtext NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddOrderProofOfDeliveryAndOtp') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911170000_AddOrderProofOfDeliveryAndOtp', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

-- ------------------------------------------------------------------------------
-- SECTION: ACCOUNTING & LEDGER
-- ------------------------------------------------------------------------------
START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    CREATE TABLE `Accounting_Bills` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `MerchantId` int NOT NULL,
        `MerchantAmount` decimal(65,30) NOT NULL,
        `TotalAmount` decimal(65,30) NOT NULL,
        `JTakAmount` decimal(65,30) NOT NULL,
        `JTakAdditionalAmount` decimal(65,30) NOT NULL,
        `PaymentMethod` int NOT NULL,
        `DueDate` datetime(6) NOT NULL,
        `OrderId` int NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Bills` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    CREATE TABLE `Accounting_Payments` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `ToUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `ToUser` longtext CHARACTER SET utf8mb4 NULL,
        `ByUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `ByUser` longtext CHARACTER SET utf8mb4 NULL,
        `Amount` decimal(65,30) NOT NULL,
        `NewBalance` decimal(65,30) NOT NULL,
        `HandoverDate` datetime(6) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Payments` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    CREATE TABLE `Accounting_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Settings` PRIMARY KEY (`Key`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203093913_initAccountingDb') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203093913_initAccountingDb', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203143309_addedBalances') THEN

    CREATE TABLE `Accounting_Balances` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `Amount` decimal(65,30) NOT NULL,
        `PendingAmount` decimal(65,30) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Balances` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220203143309_addedBalances') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220203143309_addedBalances', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220318143205_improvedHandOverDate') THEN

    ALTER TABLE `Accounting_Payments` MODIFY COLUMN `HandoverDate` datetime(6) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220318143205_improvedHandOverDate') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220318143205_improvedHandOverDate', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220325140922_improvedBalances') THEN

    ALTER TABLE `Accounting_Balances` DROP COLUMN `PendingAmount`;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220325140922_improvedBalances') THEN

    ALTER TABLE `Accounting_Balances` ADD `Name` longtext CHARACTER SET utf8mb4 NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220325140922_improvedBalances') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220325140922_improvedBalances', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220328124235_revertedToPendingBalances') THEN

    ALTER TABLE `Accounting_Bills` ADD `IsAddedToDues` tinyint(1) NOT NULL DEFAULT FALSE;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220328124235_revertedToPendingBalances') THEN

    ALTER TABLE `Accounting_Balances` ADD `PendingAmount` decimal(65,30) NOT NULL DEFAULT 0.0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220328124235_revertedToPendingBalances') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220328124235_revertedToPendingBalances', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_Accounts` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `AccountCode` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `Name` varchar(200) CHARACTER SET utf8mb4 NOT NULL,
        `Type` int NOT NULL,
        `Currency` varchar(10) CHARACTER SET utf8mb4 NOT NULL,
        `OwnerUserId` char(36) COLLATE ascii_general_ci NULL,
        `OwnerMerchantId` int NULL,
        `IsActive` tinyint(1) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_Accounts` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_DailySettlementBatches` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `BatchCode` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `CaptainUserId` char(36) COLLATE ascii_general_ci NOT NULL,
        `BatchDate` datetime(6) NOT NULL,
        `TotalCashCollected` decimal(18,2) NOT NULL,
        `TotalWagesEarned` decimal(18,2) NOT NULL,
        `NetCashRemitted` decimal(18,2) NOT NULL,
        `DiscrepancyAmount` decimal(18,2) NOT NULL,
        `DiscrepancyReason` varchar(500) CHARACTER SET utf8mb4 NULL,
        `HandledByAdminId` char(36) COLLATE ascii_general_ci NOT NULL,
        `SettlementTransactionId` char(36) COLLATE ascii_general_ci NOT NULL,
        `IsLocked` tinyint(1) NOT NULL,
        `Notes` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_DailySettlementBatches` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_JournalTransactions` (
        `Id` char(36) COLLATE ascii_general_ci NOT NULL,
        `TransactionNumber` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `PostedDate` datetime(6) NOT NULL,
        `ReferenceType` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `ReferenceId` varchar(100) CHARACTER SET utf8mb4 NOT NULL,
        `IdempotencyKey` varchar(150) CHARACTER SET utf8mb4 NULL,
        `Description` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_JournalTransactions` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE TABLE `Accounting_LedgerEntries` (
        `Id` bigint NOT NULL AUTO_INCREMENT,
        `JournalTransactionId` char(36) COLLATE ascii_general_ci NOT NULL,
        `AccountId` char(36) COLLATE ascii_general_ci NOT NULL,
        `Debit` decimal(18,2) NOT NULL,
        `Credit` decimal(18,2) NOT NULL,
        `Currency` varchar(10) CHARACTER SET utf8mb4 NOT NULL,
        `Memo` varchar(500) CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Accounting_LedgerEntries` PRIMARY KEY (`Id`),
        CONSTRAINT `FK_Accounting_LedgerEntries_Accounting_Accounts_AccountId` FOREIGN KEY (`AccountId`) REFERENCES `Accounting_Accounts` (`Id`) ON DELETE RESTRICT,
        CONSTRAINT `FK_Accounting_LedgerEntries_Accounting_JournalTransactions_Jour~` FOREIGN KEY (`JournalTransactionId`) REFERENCES `Accounting_JournalTransactions` (`Id`) ON DELETE RESTRICT
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE UNIQUE INDEX `IX_Accounting_Accounts_AccountCode` ON `Accounting_Accounts` (`AccountCode`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_Accounts_OwnerMerchantId` ON `Accounting_Accounts` (`OwnerMerchantId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_Accounts_OwnerUserId` ON `Accounting_Accounts` (`OwnerUserId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE UNIQUE INDEX `IX_Accounting_DailySettlementBatches_BatchCode` ON `Accounting_DailySettlementBatches` (`BatchCode`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_DailySettlementBatches_CaptainUserId_BatchDate` ON `Accounting_DailySettlementBatches` (`CaptainUserId`, `BatchDate`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_JournalTransactions_IdempotencyKey` ON `Accounting_JournalTransactions` (`IdempotencyKey`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_JournalTransactions_ReferenceType_ReferenceId` ON `Accounting_JournalTransactions` (`ReferenceType`, `ReferenceId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE UNIQUE INDEX `IX_Accounting_JournalTransactions_TransactionNumber` ON `Accounting_JournalTransactions` (`TransactionNumber`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_LedgerEntries_AccountId_Currency` ON `Accounting_LedgerEntries` (`AccountId`, `Currency`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    CREATE INDEX `IX_Accounting_LedgerEntries_JournalTransactionId` ON `Accounting_LedgerEntries` (`JournalTransactionId`);

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911120259_AddDoubleEntryLedgerTables') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911120259_AddDoubleEntryLedgerTables', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

-- ------------------------------------------------------------------------------
-- SECTION: SHIPPING & LOGISTICS
-- ------------------------------------------------------------------------------
START TRANSACTION;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220423105008_addedShippingDbStuff') THEN

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220423105008_addedShippingDbStuff') THEN

    CREATE TABLE `Shipping_Settings` (
        `Key` varchar(255) CHARACTER SET utf8mb4 NOT NULL,
        `Value` longtext CHARACTER SET utf8mb4 NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Shipping_Settings` PRIMARY KEY (`Key`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220423105008_addedShippingDbStuff') THEN

    CREATE TABLE `Shipping_ShippingOrders` (
        `Id` int NOT NULL AUTO_INCREMENT,
        `Index` int NOT NULL,
        `OrderId` int NOT NULL,
        `DriverId` char(36) COLLATE ascii_general_ci NOT NULL,
        `MerchantId` int NULL,
        `CustomerId` char(36) COLLATE ascii_general_ci NULL,
        `CompletedDate` datetime(6) NULL,
        `Lat` decimal(65,30) NOT NULL,
        `Lng` decimal(65,30) NOT NULL,
        `CreatedDate` datetime(6) NOT NULL,
        `CreatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        `UpdatedDate` datetime(6) NOT NULL,
        `UpdatedBy` varchar(256) CHARACTER SET utf8mb4 NULL,
        CONSTRAINT `PK_Shipping_ShippingOrders` PRIMARY KEY (`Id`)
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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20220423105008_addedShippingDbStuff') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20220423105008_addedShippingDbStuff', '6.0.12');

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
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddShippingStopDetails') THEN

    ALTER TABLE `Shipping_ShippingOrders` ADD `StopType` tinyint unsigned NOT NULL DEFAULT 0;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddShippingStopDetails') THEN

    ALTER TABLE `Shipping_ShippingOrders` ADD `StopTitle` varchar(128) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddShippingStopDetails') THEN

    ALTER TABLE `Shipping_ShippingOrders` ADD `IsDarkStore` tinyint(1) NOT NULL DEFAULT FALSE;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddShippingStopDetails') THEN

    ALTER TABLE `Shipping_ShippingOrders` ADD `VerificationCode` varchar(32) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddShippingStopDetails') THEN

    ALTER TABLE `Shipping_ShippingOrders` ADD `Notes` varchar(256) NULL;

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260911170000_AddShippingStopDetails') THEN

    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260911170000_AddShippingStopDetails', '6.0.12');

    END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

COMMIT;

-- ==============================================================================
-- BUSINESS TAXONOMY & SEED DATA
-- ==============================================================================

-- Seed Standard Roles if not present
INSERT IGNORE INTO `AspNetRoles` (`Id`, `Name`, `NormalizedName`, `ConcurrencyStamp`) VALUES
('e1a10001-0000-0000-0000-000000000001', 'Admin', 'ADMIN', UUID()),
('e1a10001-0000-0000-0000-000000000002', 'Merchant', 'MERCHANT', UUID()),
('e1a10001-0000-0000-0000-000000000003', 'Delivery', 'DELIVERY', UUID()),
('e1a10001-0000-0000-0000-000000000004', 'Customer', 'CUSTOMER', UUID());

-- Seed Standard System Chart of Accounts
INSERT IGNORE INTO `Accounting_Accounts` (`Id`, `AccountCode`, `Name`, `Type`, `Currency`, `IsActive`, `CreatedDate`, `UpdatedDate`) VALUES
('11111111-1111-1111-1111-111111111101', '1010-CASH-SAFE', 'Central Vault / Company Cash Safe', 0, 'SYP', 1, NOW(6), NOW(6)),
('11111111-1111-1111-1111-111111111102', '1020-BANK-MAIN', 'Main Commercial Bank Account', 0, 'SYP', 1, NOW(6), NOW(6)),
('11111111-1111-1111-1111-111111111103', '1030-PGW-CLEARING', 'Payment Gateway Clearing Account', 0, 'SYP', 1, NOW(6), NOW(6)),
('22222222-2222-2222-2222-222222222201', '2010-AP-MERCHANT', 'Accounts Payable - Merchants Control', 1, 'SYP', 1, NOW(6), NOW(6)),
('22222222-2222-2222-2222-222222222202', '2020-AP-CAPTAIN', 'Accounts Payable - Captain Wages Control', 1, 'SYP', 1, NOW(6), NOW(6)),
('33333333-3333-3333-3333-333333333301', '3010-EQUITY-CAPITAL', 'Owner Capital & Retained Earnings', 2, 'SYP', 1, NOW(6), NOW(6)),
('44444444-4444-4444-4444-444444444401', '4010-REV-COMMISSION', 'Revenue - Platform Commission', 3, 'SYP', 1, NOW(6), NOW(6)),
('44444444-4444-4444-4444-444444444402', '4020-REV-DELIVERY', 'Revenue - Delivery Fees Collected', 3, 'SYP', 1, NOW(6), NOW(6)),
('44444444-4444-4444-4444-444444444404', '4040', 'JTAK Market Sales Revenue', 3, 'SYP', 1, NOW(6), NOW(6)),
('55555555-5555-5555-5555-555555555501', '5010-EXP-MERCHANT-COST', 'Cost of Goods Sold - Merchant Cost', 4, 'SYP', 1, NOW(6), NOW(6)),
('55555555-5555-5555-5555-555555555502', '5020-EXP-CAPTAIN-PAYOUT', 'Cost of Delivery - Captain Payouts', 4, 'SYP', 1, NOW(6), NOW(6));

-- Classify unclassified merchants (MerchantKind = 0) based on title/description keywords
UPDATE `Catalog_Merchant`
SET `MerchantKind` = CASE
    WHEN LOWER(CONCAT(COALESCE(`Title`, ''), ' ', COALESCE(`ShortDescription`, ''))) REGEXP 'صيدلي|pharmacy|drugstore' THEN 2
    WHEN LOWER(CONCAT(COALESCE(`Title`, ''), ' ', COALESCE(`ShortDescription`, ''))) REGEXP 'سوبرماركت|سوبر ماركت|بقالة|تموينات|hypermarket|grocery|market|mart' THEN 1
    WHEN LOWER(CONCAT(COALESCE(`Title`, ''), ' ', COALESCE(`ShortDescription`, ''))) REGEXP 'متجر|مول|shop|store|mall|cosmetic|تجميل' THEN 3
    ELSE `MerchantKind`
END
WHERE `MerchantKind` = 0;

-- Settlement request workflow (captain cash handover + merchant payout)
CREATE TABLE IF NOT EXISTS `Accounting_SettlementRequests` (
  `Id` char(36) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
  `RequestNumber` varchar(80) NOT NULL,
  `PartyType` tinyint unsigned NOT NULL,
  `Status` tinyint unsigned NOT NULL,
  `RequestedByUserId` char(36) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
  `RequestedByName` varchar(200) NULL,
  `RequestedByPhone` varchar(40) NULL,
  `Amount` decimal(18,2) NOT NULL,
  `Currency` varchar(8) NOT NULL DEFAULT 'SYP',
  `Method` varchar(80) NULL,
  `AccountDetails` varchar(500) NULL,
  `Notes` varchar(500) NULL,
  `RejectionReason` varchar(500) NULL,
  `ReviewedByAdminId` char(36) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
  `ReviewedAt` datetime(6) NULL,
  `CompletedByAdminId` char(36) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
  `CompletedAt` datetime(6) NULL,
  `LedgerTransactionId` char(36) CHARACTER SET ascii COLLATE ascii_general_ci NULL,
  `CreatedDate` datetime(6) NOT NULL,
  `CreatedBy` varchar(256) NULL,
  `UpdatedDate` datetime(6) NOT NULL,
  `UpdatedBy` varchar(256) NULL,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `IX_Accounting_SettlementRequests_RequestNumber` (`RequestNumber`),
  KEY `IX_Accounting_SettlementRequests_PartyType_Status_CreatedDate` (`PartyType`,`Status`,`CreatedDate`),
  KEY `IX_Accounting_SettlementRequests_RequestedByUserId_Status` (`RequestedByUserId`,`Status`)
) CHARACTER SET=utf8mb4;

CREATE TABLE IF NOT EXISTS `Accounting_SettlementRequestMerchantAllocations` (
  `Id` bigint NOT NULL AUTO_INCREMENT,
  `SettlementRequestId` char(36) CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
  `MerchantId` int NOT NULL,
  `MerchantTitle` varchar(200) NULL,
  `Amount` decimal(18,2) NOT NULL,
  PRIMARY KEY (`Id`),
  KEY `IX_SettlementAllocation_Merchant_Request` (`MerchantId`,`SettlementRequestId`),
  KEY `IX_SettlementAllocation_Request` (`SettlementRequestId`),
  CONSTRAINT `FK_SettlementAllocation_Request` FOREIGN KEY (`SettlementRequestId`)
    REFERENCES `Accounting_SettlementRequests` (`Id`) ON DELETE RESTRICT
) CHARACTER SET=utf8mb4;

INSERT IGNORE INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
VALUES ('20260915071938_AddSettlementRequestWorkflow', '6.0.12');

-- Enforce exactly-once ledger posting for retries and concurrent requests.
DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
  IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915080246_EnforceLedgerIdempotency') THEN
    DROP INDEX `IX_Accounting_JournalTransactions_IdempotencyKey` ON `Accounting_JournalTransactions`;
    CREATE UNIQUE INDEX `IX_Accounting_JournalTransactions_IdempotencyKey`
      ON `Accounting_JournalTransactions` (`IdempotencyKey`);
    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915080246_EnforceLedgerIdempotency', '6.0.12');
  END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

-- Enforce unique constraint on Bill (OrderId, MerchantId) to prevent duplicate bills during courier pickup races.
DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
  IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915123000_AddUniqueConstraintToBillOrderIdMerchantId') THEN
    IF NOT EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'Accounting_Bills' AND index_name = 'IX_Accounting_Bills_OrderId_MerchantId') THEN
      CREATE UNIQUE INDEX `IX_Accounting_Bills_OrderId_MerchantId`
        ON `Accounting_Bills` (`OrderId`, `MerchantId`);
    END IF;
    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915123000_AddUniqueConstraintToBillOrderIdMerchantId', '6.0.12');
  END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

-- Add picking audit fields to Catalog_BatchReservations
DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
  IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260915163000_AddPickingFieldsToBatchReservation') THEN
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_BatchReservations' AND column_name = 'IsPicked') THEN
      ALTER TABLE `Catalog_BatchReservations` ADD `IsPicked` tinyint(1) NOT NULL DEFAULT 0;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_BatchReservations' AND column_name = 'PickedDate') THEN
      ALTER TABLE `Catalog_BatchReservations` ADD `PickedDate` datetime(6) NULL;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_BatchReservations' AND column_name = 'PickedBy') THEN
      ALTER TABLE `Catalog_BatchReservations` ADD `PickedBy` varchar(128) CHARACTER SET utf8mb4 NULL;
    END IF;
    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260915163000_AddPickingFieldsToBatchReservation', '6.0.12');
  END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

-- Add Delivery Policy fields to Catalog_Merchant
DROP PROCEDURE IF EXISTS MigrationsScript;
DELIMITER //
CREATE PROCEDURE MigrationsScript()
BEGIN
  IF NOT EXISTS(SELECT 1 FROM `__EFMigrationsHistory` WHERE `MigrationId` = '20260914230000_addMerchantDeliveryPolicyFields') THEN
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_Merchant' AND column_name = 'DeliveryTime') THEN
      ALTER TABLE `Catalog_Merchant` ADD `DeliveryTime` VARCHAR(64) NOT NULL DEFAULT '20-30 دقيقة';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_Merchant' AND column_name = 'DeliveryFee') THEN
      ALTER TABLE `Catalog_Merchant` ADD `DeliveryFee` DECIMAL(18,2) NOT NULL DEFAULT 5000.00;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_Merchant' AND column_name = 'MinOrderAmount') THEN
      ALTER TABLE `Catalog_Merchant` ADD `MinOrderAmount` DECIMAL(18,2) NOT NULL DEFAULT 15000.00;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'Catalog_Merchant' AND column_name = 'WorkingHours') THEN
      ALTER TABLE `Catalog_Merchant` ADD `WorkingHours` VARCHAR(128) NOT NULL DEFAULT 'حتى 3 ص';
    END IF;
    INSERT INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
    VALUES ('20260914230000_addMerchantDeliveryPolicyFields', '6.0.12');
  END IF;
END //
DELIMITER ;
CALL MigrationsScript();
DROP PROCEDURE MigrationsScript;

-- Add SupportMessages Table
CREATE TABLE IF NOT EXISTS `SupportMessages` (
    `Id` INT NOT NULL AUTO_INCREMENT,
    `UserId` VARCHAR(36) NULL,
    `SenderName` VARCHAR(150) NULL,
    `SenderPhone` VARCHAR(50) NULL,
    `SenderEmail` VARCHAR(150) NULL,
    `Title` VARCHAR(200) NULL,
    `Message` LONGTEXT NULL,
    `Status` INT NOT NULL DEFAULT 0,
    `AdminNotes` LONGTEXT NULL,
    `ResolvedDate` DATETIME(6) NULL,
    `CreatedBy` VARCHAR(256) NULL,
    `CreatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    `UpdatedBy` VARCHAR(256) NULL,
    `UpdatedDate` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (`Id`),
    INDEX `IX_SupportMessages_Status` (`Status`),
    INDEX `IX_SupportMessages_CreatedDate` (`CreatedDate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `__EFMigrationsHistory` (`MigrationId`, `ProductVersion`)
VALUES ('20260915150000_AddSupportMessages', '6.0.12');

SET FOREIGN_KEY_CHECKS = 1;

