-- ===============================================================================================
-- ===============================================================================================
-- Purpose: Deployment script for PowerSTIG database objects
-- Revisions:
-- ===============================================================================================
-- ===============================================================================================
/*
  Copyright (C) 2019 Microsoft Corporation
  Disclaimer:
        This is SAMPLE code that is NOT production ready. It is the sole intention of this code to provide a proof of concept as a
        learning tool for Microsoft Customers. Microsoft does not provide warranty for or guarantee any portion of this code
        and is NOT responsible for any affects it may have on any system it is executed on or environment it resides within.
        Please use this code at your own discretion!
  Additional legalize:
        This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
    We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
    the object code form of the Sample Code, provided that You agree:
                  (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
         (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
         (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys� fees,
               that arise or result from the use or distribution of the Sample Code.
*/
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @UpdateVersion smallint
DECLARE @CurrentVersion smallint
SET @UpdateVersion = 500
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
	IF OBJECT_ID('PowerSTIG.DBversion') IS NOT NULL
		BEGIN
			IF EXISTS (SELECT VersionID FROM PowerSTIG.DBversion WHERE UpdateVersion = @UpdateVersion AND isActive = 1)
				BEGIN
					   	SET @StepMessage = 'Update version ['+CAST(@UpdateVersion as varchar(5))+'] already applied.  This is an informational message only.'
			            SET @StepAction = 'DEPLOY'
			            PRINT @StepMessage
					--
			            EXEC PowerSTIG.sproc_InsertScanLog
			            	@LogEntryTitle = @StepName
			                ,@LogMessage = @StepMessage
			                ,@ActionTaken = @StepAction
                    --
                    -- Bail out of this script.  Already applied.
					SELECT 8675309 AS UpdateApplied;
					THROW 8675309, 'Database update previously applied.  This is an informational message only.', 1
				END
		END
-- ===============================================================================================
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerStigScan database object deployment start - '+CONVERT(VARCHAR,GETDATE(), 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
-- ===============================================================================================
DROP TABLE IF EXISTS __PowerStigDBdeployVersion
--
CREATE TABLE __PowerStigDBdeployVersion (UpdateVersion smallint,CurrentVersion smallint)
--
INSERT INTO __PowerStigDBdeployVersion (UpdateVersion,CurrentVersion) VALUES (@UpdateVersion,NULL)
--
	SET @StepMessage = 'Update version ['+CAST(@UpdateVersion as varchar(5))+'] not yet applied.  Executing script now.  This is an informational message only.'
	SET @StepAction = 'DEPLOY'
	PRINT @StepMessage
	--
	EXEC PowerSTIG.sproc_InsertScanLog
	        	@LogEntryTitle = @StepName
	           ,@LogMessage = @StepMessage
	           ,@ActionTaken = @StepAction
    --
    INSERT INTO PowerSTIG.DBversion (UpdateVersion,VersionTS,isActive,VersionNotes)
           VALUES
              (@UpdateVersion,GETDATE(),0,NULL)
-- ===============================================================================================
-- ===============================================================================================
-- Drop constraints
-- ===============================================================================================
PRINT 'Begin drop constraints'
--
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_ComplianceType]
--
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_TargetComputer]
--
IF (OBJECT_ID('PowerSTIG.FK_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[TargetTypeMap] DROP CONSTRAINT [FK_TargetComputer]
--
IF (OBJECT_ID('PowerSTIG.FK_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[TargetTypeMap] DROP CONSTRAINT [FK_ComplianceType]
--
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_FindingCategory', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_FindingCategory]
--
IF (OBJECT_ID('PowerSTIG.FK_ComplianceCheckLog_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[ComplianceCheckLog] DROP CONSTRAINT [FK_ComplianceCheckLog_TargetComputer]
--
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_Finding', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_Finding]
--
IF (OBJECT_ID('PowerSTIG.FK_ComplianceCheckLog_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[ComplianceCheckLog] DROP CONSTRAINT [FK_ComplianceCheckLog_ComplianceType]
--
PRINT 'End drop constraints'
GO
-- ===============================================================================================
-- Drop tables
-- ===============================================================================================
PRINT 'Begin drop tables'
--
	DROP TABLE IF EXISTS PowerSTIG.TargetTypeMap
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceTypes
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceTargets
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceIteration
--
	DROP TABLE IF EXISTS PowerSTIG.FindingImport
--
	DROP TABLE IF EXISTS PowerSTIG.UnreachableTargets
--
	DROP TABLE IF EXISTS PowerSTIG.FindingImportFiles
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceCheckLog
--
	DROP TABLE IF EXISTS PowerSTIG.FindingRepo
--
	DROP TABLE IF EXISTS PowerSTIG.DupFindingFileCheck
--
	DROP TABLE IF EXISTS PowerSTIG.FindingSubPlatform
--
	DROP TABLE IF EXISTS PowerSTIG.ScanImportLog
--	
	DROP TABLE IF EXISTS PowerSTIG.ScanImportErrorLog
--
	DROP TABLE IF EXISTS PowerStig.ScanQueue
--
	DROP TABLE IF EXISTS PowerSTIG.FindingCategory
--
	DROP TABLE IF EXISTS PowerSTIG.FindingSeverity
--
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion')AS smallint)) >= 13
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd =' 
		IF OBJECT_ID (''PowerSTIG.ComplianceConfig'') IS NOT NULL
			BEGIN
				ALTER TABLE [PowerSTIG].[ComplianceConfig] SET ( SYSTEM_VERSIONING = OFF)
				DROP TABLE IF EXISTS PowerSTIG.ComplianceConfigHistory
			END'
		EXEC(@SQLcmd)
	END
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceConfig
--
	DROP TABLE IF EXISTS PowerSTIG.Finding
--
	DROP TABLE IF EXISTS PowerSTIG.Scans
--
	DROP TABLE IF EXISTS PowerSTIG.MemberServerSTIG
--
	DROP TABLE IF EXISTS PowerSTIG.OrgSettingsRepo
--
	DROP TABLE IF EXISTS PowerSTIG.FireFoxSTIG
--
	DROP TABLE IF EXISTS PowerSTIG.AdminFunction
--
	DROP TABLE IF EXISTS PowerSTIG.AdminFunctionUsers
--
	DROP TABLE IF EXISTS PowerSTIG.AdminFunctionsMap
--
	DROP TABLE IF EXISTS PowerSTIG.StigText
--
	DROP TABLE IF EXISTS PowerSTIG.StigTextRepo
--
	DROP TABLE IF EXISTS PowerSTIG.ScanSource
--
	DROP TABLE IF EXISTS PowerSTIG.TargetTypeOS
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceTypesInfo
--
	DROP TABLE IF EXISTS PowerSTIG.RSpages
--
	DROP TABLE IF EXISTS PowerSTIG.ComplianceTargetRoles
--
PRINT 'End drop tables'
GO
-- ===============================================================================================
-- Drop views
-- ===============================================================================================
PRINT 'Begin drop views'
	DROP VIEW IF EXISTS PowerSTIG.vw_TargetTypeMap
--
	DROP VIEW IF EXISTS PowerSTIG.v_BulkFindingImport
--
	DROP VIEW IF EXISTS PowerSTIG.ComplianceSourceMap
PRINT 'End drop views'
GO
-- ===============================================================================================
-- Create tables
-- ===============================================================================================
PRINT 'Begin create tables'
----
CREATE TABLE PowerSTIG.Scans (
	[ScanID] [int] IDENTITY(1,1) NOT NULL,
	[ScanGUID] [char](36) NOT NULL,
	[ScanSourceID] smallint NOT NULL,
	[ScanDate] [datetime] NOT NULL,
    [ScanVersion] varchar(8) NULL,
	[isProcessed] [bit] NOT NULL DEFAULT(0))
--
CREATE TABLE [PowerSTIG].[FindingSeverity](
	[FindingSeverityID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[FindingSeverity] [varchar](128) NOT NULL)
--
CREATE TABLE PowerSTIG.FindingCategory(
	FindingCategoryID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FindingCategory varchar(128) NOT NULL)
--
CREATE TABLE PowerSTIG.Finding(
	FindingID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	Finding varchar(128) NOT NULL,
	FindingText varchar(768) NULL)
--
CREATE TABLE PowerSTIG.ComplianceTargets (
	TargetComputerID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputer varchar(256) NOT NULL UNIQUE,
	isActive BIT NOT NULL DEFAULT(1),
	LastComplianceCheck datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'),
    OSid smallint NOT NULL DEFAULT(0),
    [IPv4address] varchar(15) NULL,
	[IPv6address] varchar(45) NULL,
	[MACaddress] varchar(17) NULL,
	[FQDN] varchar(384) NULL)
--
CREATE TABLE PowerSTIG.ComplianceTypes (
	ComplianceTypeID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ComplianceType varchar(256) NOT NULL UNIQUE,
	isActive BIT NOT NULL DEFAULT(1))
--
CREATE TABLE PowerSTIG.ComplianceCheckLog(
	CheckLogID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ScanID INT NOT NULL,
	TargetComputerID INT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	LastComplianceCheck datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
--
CREATE TABLE PowerSTIG.FindingRepo(
	[TargetComputerID] [int] NOT NULL,
	[FindingID] [int] NOT NULL,
	[InDesiredState] [bit] NOT NULL,
	[ComplianceTypeID] [int] NOT NULL,
	[ScanID] [int] NOT NULL)
--
CREATE TABLE PowerStig.ScanQueue (
	ScanQueueID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputer varchar(256) NOT NULL,
	ComplianceType varchar(256) NOT NULL,
	QueueStart datetime NOT NULL,
	QueueEnd datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
--
CREATE TABLE PowerSTIG.ComplianceConfig (
			ConfigID SMALLINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
			ConfigProperty varchar(256) NOT NULL,
			ConfigSetting varchar(256) NOT NULL,
			ConfigNote varchar(1000) NULL,
			SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL,  
			SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL,
				PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime))
				WITH
				(   
				  SYSTEM_VERSIONING = ON (HISTORY_TABLE = PowerSTIG.ComplianceConfigHistory)   
				)
--
CREATE TABLE PowerSTIG.FindingImport (
	[TargetComputer] [varchar](255) NULL,
	[VulnID] [varchar](25) NULL,
	[StigType] [varchar](256) NULL,
	[DesiredState] [varchar](25) NULL,
	[ScanDate] [datetime] NULL,
	[GUID] [char](36) NULL,
	[ScanSource] varchar(25) NULL,
	[ImportDate] [datetime] NULL,
    [ScanVersion] varchar(8) NULL)
--
CREATE TABLE PowerSTIG.AdminFunction (
	FunctionID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FunctionName varchar(128) NOT NULL UNIQUE,
	FunctionDescription varchar(768) NOT NULL DEFAULT('No function description specified.'),
	FunctionPage varchar(128) NULL,
	isActive BIT NOT NULL DEFAULT(0))
--
CREATE TABLE PowerSTIG.AdminFunctionUsers (
	AdminID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FQDNandAdmin varchar(256) NOT NULL UNIQUE)
--
CREATE TABLE PowerSTIG.AdminFunctionsMap (
	FunctionMapID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FunctionID smallint NOT NULL,
	AdminID smallint NOT NULL,
	isActive BIT NOT NULL DEFAULT(1))
--
CREATE TABLE [PowerSTIG].[StigTextRepo](
	[TextID] [int] IDENTITY(1,1) NOT NULL,
	[RuleID] [nvarchar](25) NOT NULL,
	[Severity] [nvarchar](25) NOT NULL,
	[Title] [nvarchar](1000) NOT NULL,
	[DSCresource] [nvarchar](256) NOT NULL,
	[RawString] [nvarchar](max) NOT NULL)
--
CREATE TABLE PowerSTIG.ScanSource (
			ScanSourceID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
			ScanSource varchar(25) NOT NULL UNIQUE)
--
CREATE TABLE PowerSTIG.TargetTypeOS(
        OSid smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        OSname varchar(256) NOT NULL UNIQUE)
--
CREATE TABLE PowerSTIG.OrgSettingsRepo (
    OrgRepoID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TypesInfoID INT NOT NULL,
    Finding varchar(128) NULL,
    OrgValue varchar(4000)NULL)
--
CREATE TABLE PowerSTIG.ComplianceTypesInfo (
	TypesInfoID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ComplianceTypeID INT NOT NULL,
	OSid smallint NOT NULL DEFAULT(0),
	OrgValue varchar(10),
	OrgSettingAlias varchar(128) NOT NULL,
	OrgSettingFile varchar(256) NOT NULL)
--
CREATE TABLE PowerSTIG.RSpages (
    RSpageID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PageName varchar(256) NOT NULL UNIQUE,
    ReportName varchar(256) NOT NULL UNIQUE,
    PageDescription varchar(512) NULL,
    ReportOrder smallint NOT NULL DEFAULT(2),
    isActive BIT NOT NULL DEFAULT(1))
--
CREATE TABLE PowerSTIG.ComplianceTargetRoles (
	TargetRoleID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputerID INT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	LastScanID INT NOT NULL)	
--
PRINT 'End create tables'
-- ===============================================================================================
-- Create views
-- ===============================================================================================
PRINT 'Begin create views'
GO
CREATE OR ALTER VIEW PowerSTIG.ComplianceSourceMap
AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- PURPOSE: Combines Scans.ScanSourceID with ComplianceCheckLog for simplified queries.
-- REVISIONS:
-- 05212019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
-- SELECT * FROM PowerSTIG.ComplianceSourceMap
-- ===============================================================================================
	SELECT
		L.ScanID
		,L.TargetComputerID
		,L.ComplianceTypeID
		,S.ScanSourceID
		,L.LastComplianceCheck
	FROM
		PowerSTIG.ComplianceCheckLog L
			JOIN
				PowerSTIG.Scans S
			ON
				L.ScanID = S.ScanID
GO
-- ===============================================================================================
-- Hydrate ComplianceConfig table
-- ===============================================================================================
PRINT 'Hydrating PowerSTIG.ComplianceConfig table'
--
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('FindingRepoTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckAlert','OFF','Possible values are ON or OFF.  Controls whether the last compliance type checks for a target computer has violated the LastComplianceCheckInDays threshold.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckInDays','90','Specifies the number of days that a compliance type check for a target computer may not occur.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckAlertRecipients','Replace with valid email addresses','Recipient(s) for PowerStigScan notifications')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ComplianceCheckLogTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('FindingImportFilesTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('MailProfileName','Replace with SQL Mail Profile Name','SQL Server Database Mail profile for use with sending outbound mail')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanImportLogRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanImportErrorLogRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanLogRetentionDays','730','This setting controls the number of days of history to store in the PowerSTIG.ScanLog table.')
    INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ORGsettingXML','C:\Program Files\WindowsPowerShell\Modules\PowerSTIG\3.1.0\StigData\Processed','This setting sets the location of the PowerStig ORG setting XML files.')
GO
-- ===============================================================================================
-- Hydrate compliance types
-- ===============================================================================================
PRINT 'Hydrating compliance types in PowerSTIG.ComplianceTypes'
--
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('DotNetFramework',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('FireFox',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('IISServer',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('IISSite',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('InternetExplorer',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Excel2013',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Outlook2013',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('PowerPoint2013',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Word2013',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('OracleJRE',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('SqlServer-2012-Database',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('SqlServer-2012-Instance',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('SqlServer-2016-Instance',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('WindowsClient',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('WindowsDefender',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('WindowsDNSServer',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('WindowsFirewall',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('WindowsServer-DC',1)
    INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('WindowsServer-MS',1)
	--
GO
-- ===============================================================================================
-- Hydrate AdminFunction
-- ===============================================================================================
PRINT 'Hydrating admin functions in PowerSTIG.AdminFunction'
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive) VALUES ('View Scan Log','View the Scan Log','ScanLog',1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('View Scan Queue',DEFAULT,'QueuedScans',1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('Add Target Computer',DEFAULT,'AddTargetComputer',1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('Initiate Scan',DEFAULT,NULL,1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('Modify Target Computer Roles',DEFAULT,NULL,1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('Modify ORG settings',DEFAULT,NULL,1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('View ORG settings',DEFAULT,NULL,1)
	INSERT INTO PowerSTIG.AdminFunction (FunctionName,FunctionDescription,FunctionPage,isActive)  VALUES ('Add ORG setting',DEFAULT,NULL,1)
GO
-- ===============================================================================================
-- Hydrate ScanSource
-- ===============================================================================================
PRINT 'Hydrating PowerSTIG.ScanSource'
    INSERT INTO PowerSTIG.ScanSource (ScanSource) VALUES ('SCAP')
	INSERT INTO PowerSTIG.ScanSource (ScanSource) VALUES ('POWERSTIG')
GO
-- ===============================================================================================
-- Hydrate TargetTypeOS
-- ===============================================================================================
PRINT 'Hydrating PowerSTIG.TargetTypeOS'
    INSERT INTO PowerSTIG.TargetTypeOS (OSname) VALUES ('2012R2')
    INSERT INTO PowerSTIG.TargetTypeOS (OSname) VALUES ('2016')
    INSERT INTO PowerSTIG.TargetTypeOS (OSname) VALUES ('10')
    INSERT INTO PowerSTIG.TargetTypeOS (OSname) VALUES ('ALL')
GO
-- ===============================================================================================
-- Hydrate RSpages
-- ===============================================================================================
PRINT 'Hydrating PowerSTIG.RSpages'
	INSERT INTO powerstig.rspages VALUES ('View Org Settings','ViewOrgSettings','This report displays the current ORG specific settings.',2,1)
	INSERT INTO powerstig.rspages VALUES ('View Scan Queue','ScanQueue','This report displays the current scan queue.',2,1)
	INSERT INTO powerstig.rspages VALUES ('Last Compliance Check','LastComplianceCheckByRoleAndTarget','This report displays the last compliance check by target computer and role.',2,1)
	INSERT INTO powerstig.rspages VALUES ('Edit Org Settings','EditOrgSettings','Use this page to modify and save ORG settings.',2,0)
	INSERT INTO powerstig.rspages VALUES ('Detailed Scan Results','DetailedScanResults','Use this report to view scan results by target and role with full STIG text.',2,1)
	INSERT INTO powerstig.rspages VALUES ('PowerSTIGscan Dashboard','PowerSTIGdashboardV1','Main report.',1,1)
	INSERT INTO powerstig.rspages VALUES ('View Scan Log','ViewScanLog','Use this report to view Scan Log entries for a specific date.',2,1)
GO
-- ===============================================================================================
-- Create constraints
-- ===============================================================================================
PRINT 'Begin create constraints'
--
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
--
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
--
ALTER TABLE PowerSTIG.ComplianceCheckLog WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceCheckLog_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
--
ALTER TABLE PowerSTIG.ComplianceCheckLog WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceCheckLog_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
--
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_Finding]
	FOREIGN KEY (FindingID) REFERENCES [PowerSTIG].[Finding] (FindingID)
--
PRINT 'End create constraints'
GO
-- ===============================================================================================
-- Indexes
-- ===============================================================================================
PRINT 'Begin create indexes'
--
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_ConfigProperty')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_ConfigProperty ON PowerSTIG.ComplianceConfig(ConfigProperty)
--
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_FunctionAdmin')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_FunctionAdmin ON PowerSTIG.AdminFunctionsMap (FunctionID,AdminID)
--
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_TargetComplianceCheck')
	CREATE NONCLUSTERED INDEX [IX_TargetComplianceCheck] ON PowerSTIG.ComplianceCheckLog(TargetComputerID,ComplianceTypeID,LastComplianceCheck)
--
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_OrgSettingsRepo')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_OrgSettingsRepo ON PowerSTIG.OrgSettingsRepo (TypesInfoID,Finding)
--
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_Repo')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_Repo ON PowerSTIG.FindingRepo (TargetComputerID,FindingID,ComplianceTypeID,ScanID)
--
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_BaseUpdate')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_BaseUpdate ON PowerSTIG.DBversion(UpdateVersion)
PRINT 'End create indexes'
GO
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- Logging
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @UpdateVersion SMALLINT
DECLARE @CurrentVersion smallint
SET @UpdateVersion = (SELECT TOP 1 UpdateVersion FROM __PowerStigDBdeployVersion)
SET @CurrentVersion = (SELECT TOP 1 CurrentVersion FROM __PowerStigDBdeployVersion)
			SET @StepMessage = 'Update version ['+CAST(@UpdateVersion as varchar(5))+'] successfully applied. This is an informational message only.'
			SET @StepAction = 'DEPLOY'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
--
            UPDATE
                PowerSTIG.DBversion
            SET
                isActive = 1
            WHERE
                UpdateVersion = @UpdateVersion
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
	DROP TABLE IF EXISTS __PowerStigDBdeployVersion
-- ===============================================================================================
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerStigScan database object deployment complete - '+CONVERT(VARCHAR,GETDATE(), 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
-- ===============================================================================================