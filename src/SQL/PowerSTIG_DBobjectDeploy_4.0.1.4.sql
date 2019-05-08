-- ===============================================================================================
-- ===============================================================================================
-- Purpose: Deployment script for PowerSTIG database objects
-- Revisions:
-- 09172018 - v3.0.0.0 - Kevin Barlett, Microsoft - Initial creation.
-- 10302018 - v3.0.0.1 - Kevin Barlett, Microsoft - Addition of GUID input in FindingImport table and insert proc.
-- 10312018 - v3.0.1.8 - Kevin Barlett, Microsoft 
--								- Added new compliance types, removed unused and renamed existing. | Modified sproc_AddTargetComputer to accept new compliance types. |
--								- Added error handling to sproc_CreateComplianceIteration | Added error handling to sproc_CompleteComplianceIteration | Added error handling to sproc_InsertComplianceCheckLog |
--								- Added error handling to sproc_AddTargetComputer | Fixed sproc_FindingImport extended property showing in compiled proc | 
--								- Commented out FindingSubPlatform table creation.  Now unused. | Added FindingSeverity table drop/create. |
--								- Created sproc_ProcessFindings to process raw data in FindingImport | New table Scans | FindingRepo table changes: Remove IterationID,FindingCategoryID,CollectTime.  Add ScanID
-- 11162018 - v3.0.2.4 - Kevin Barlett, Microsoft
--								- Significant code cleanup to remove unneeded V1 features | New proc sproc_GetDependencies to retrieve object dependencies and relationships |
--								- Made sproc_InsertScanLog input parameters less generic and make some semblance of sense
--01072019  - v3.0.2.6 - Kevin Barlett, Microsoft
-- 								- sproc_GetLastDataForCKL missing from deployment issue | Bug fix in sproc_ProcessFindings
--01092019  - v3.0.2.7 - Kevin Barlett, Microsoft
-- 								- Fix for sproc_GetLastDataForCKL returning incorrect columns
--01232019  - v3.0.3.1 - Kevin Barlett, Microsoft
-- 								- Revised temp table handling in sproc_ProcessFindings |
--                              - Fix in GetComplianceStateByServer to handle rule overlaps - GH issue #15 | Fix in sproc_AddTargetComputer where the message being logged to the ScanLog table was NULL.
--02042019  - v3.0.3.3 - Kevin Barlett, Microsoft
--								- Addition of GUID as parameter in GetComplianceStateByServer | Modified GetLastDataForCKL to return the scan for each compliance type associated with a target.
--02082019  - v3.0.4.0 - Kevin Barlett, Microsoft
--								- New ScanLog ActionTaken types | Create database logic | SQL version check | New proc GetScanLog
--03112019  - v3.0.4.1 - Kevin Barlett, Microsoft
--                              - New proc sproc_ImportOrgSettingsXML | New proc sproc_ImportSTIGxml | New table [MemberServerSTIG] | New proc sproc_ConsumeStigJson
--04082019  - v4.0.0.0 - Kevin Barlett, Microsoft
--                              - SCAP + PowerSTIG integration changes
--04112019  - v4.0.0.3 - Kevin Barlett, Microsoft
--04232019  - v4.0.0.5 - Kevin Barlett, Microsoft
--                              - New proc sproc_ResetTargetRoles | New proc sproc_GetActiveServersRoleCount | Modify sproc_GetRolesPerServer
--04232019  - v4.0.0.6 - Kevin Barlett, Microsoft
--                              - Bug fix sproc_GetActiveServersRoleCount | New proc sproc_ComplianceTrendByTargetRole | Bug fix in GROUP BY for sproc_GetLastComplianceCheckByTarget
--                              - New procs sproc_GetComplianceTypes, sproc_GetOrgSettingsByRole, sproc_GetRSpages | New table RSpages | New proc sproc_GetDetailedScanResults
--05062019  - v4.0.0.7 - Kevin Barlett, Microsoft
--                              - Temporary logic change in sproc_GenerateORGxml | Add SQL compliance types in sproc_ImportOrgSettingsXML | Bug fix sproc_UpdateTargetOS
--                              - Additional columns in ComplianceTargets for CKL generation | New procs sproc_UpdateCKLtargetInfo, sproc_GetCKLtargetInfo
--05072019  - v4.0.0.8 - Kevin Barlett, Microsoft
--                              - Bug fix sproc_ProcessFindings | Findings.FindingText made nullable
--05072019  - v4.0.0.9 - Kevin Barlett, Microsoft
--                              - Remove or comment all references to TargetTypeMap table as it is no longer used
--05082019  - v4.0.1.1 - Kevin Barlett, Microsoft
--                              - Modify sproc_ProcessFindings to dynamically detect ComplianceTypes | Remove ComplianceType seeding from deploy script
--                              - Removed column FindingRepo.ScanSourceID | New unique index FindingRepo.IX_UNQ_Repo | Added column FindingImport.ScanSourceVersion
--                              - Modified sproc_InsertFindingImport to accept ScanSourceVersion | Modified sproc_ProcessFindings to process ScanVersion
--05082019  - v4.0.1.3 - Kevin Barlett, Microsoft
--                              - Removed unused columns from FindingImport | Matched ComplianceType and StigType lengths | ComplianceType standardization
--05082019  - v4.0.1.4 - Kevin Barlett, Microsoft
--                              - ComplianceType standardization
-- ===============================================================================================
-- ===============================================================================================
/*
Detect SQLCMD mode and disable script execution if SQLCMD mode is not supported.
To re-enable the script after enabling SQLCMD mode, execute the following:
SET NOEXEC OFF;

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
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
--  Set parameters - BEGIN SCRIPT EDIT
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
SET NOEXEC OFF;
:setvar MAIL_PROFILE        "MailProfile"						-- SQL Server Database Mail profile for use with sending outbound mail
:setvar MAIL_RECIPIENTS		"user@mail.mil"						-- Recipient(s) for PowerStigScan notifications
:setvar CMS_SERVER			"STIG"							-- SQL instance hosting scan data repository.                 
:setvar CMS_DATABASE		"PowerStig"						-- Database used for storing scan data.    
:setvar CKL_OUTPUT			"C:\Temp\PowerStig\CKL\"
:setvar CKL_ARCHIVE			"C:\Temp\PowerStig\CKL\Archive\"
:setvar ORG_SETTING_XML     "C:\Program Files\WindowsPowerShell\Modules\PowerSTIG\3.1.0\StigData\Processed"
:setvar CREATE_JOB			"Y"

-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
-- END SCRIPT EDIT - DO NOT MODIFY BELOW THIS LINE!
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
:setvar DEP_VER "4.0.1.4"
:setvar __IsSqlCmdEnabled "True"
:on error exit
-- ===============================================================================================
-- Validate SQL version
-- ===============================================================================================
	IF (SELECT CAST(SERVERPROPERTY ('ProductMajorVersion') AS smallint)) < 13
			BEGIN
				RAISERROR('Deployment failure!  PowerStigScan requires SQL Server 2016 or higher.  All editions of SQL Server 2016 and higher are supported.',16,1) WITH NOWAIT
				SET NOEXEC ON
			END
-- ===============================================================================================
--  Verify execution in SqlCmd mode
-- ===============================================================================================

IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
		RAISERROR('SQLCMD mode must be enabled to successfully execute this script.',16,1) WITH NOWAIT
        SET NOEXEC ON;
    END
--
SET NOCOUNT ON
DECLARE @DefaultDataLoc varchar(256)
DECLARE @DefaultLogLoc varchar(256)
DECLARE @SQLCMD varchar(MAX)
-- ===============================================================================================
-- Load parameters to temp table
-- ===============================================================================================
	IF OBJECT_ID('TempDB..##PowerStigScanParams') IS NOT NULL
		DROP TABLE ##PowerStigScanParams
	--
	CREATE TABLE ##PowerStigScanParams (ParamName varchar(256) NULL,ParamValue varchar(256) NULL)
	--
	INSERT INTO ##PowerStigScanParams (ParamName,ParamValue)
	SELECT
		'MAIL_PROFILE', '$(MAIL_PROFILE)'	UNION
	SELECT
		'CMS_SERVER','$(CMS_SERVER)'		UNION
	SELECT
		'CMS_DATABASE','$(CMS_DATABASE)'	UNION
	SELECT
		'CKL_OUTPUT','$(CKL_OUTPUT)'		UNION
	SELECT
		'CKL_ARCHIVE','$(CKL_ARCHIVE)'		UNION
	SELECT
		'CREATE_JOB','$(CREATE_JOB)'		
		--select * from ##PowerStigSCanParams
-- ===============================================================================================
-- If applicable, create database
-- ===============================================================================================
	IF NOT EXISTS (SELECT [name] FROM sys.databases WHERE [name] = '$(CMS_DATABASE)' AND [state]=0)
		BEGIN TRY
			PRINT '////////////////////////////////////////////////////////'
			PRINT 'Database [$(CMS_DATABASE)] does not exist.  Creating - '+CONVERT(VARCHAR,GETDATE(), 21)
			PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
		--
		-- Collect default data and log paths
		--
		SELECT
			@DefaultDataLoc = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS varchar(256)),
			@DefaultLogLoc = CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS varchar(256))

		--
		SET @SQLCMD = 'CREATE DATABASE [$(CMS_DATABASE)] ON  PRIMARY (NAME = ''$(CMS_DATABASE)_data'', FILENAME = '''+@DefaultDataLoc+'$(CMS_DATABASE)_data.mdf'' , SIZE = 128MB , MAXSIZE = UNLIMITED, FILEGROWTH = 128MB) LOG ON (NAME = ''$(CMS_DATABASE)_log'', FILENAME = '''+@DefaultLogLoc+'$(CMS_DATABASE)_log.ldf'' , SIZE = 128MB , MAXSIZE = 2048GB , FILEGROWTH =128MB)'
		--PRINT @SQLCMD
		EXEC(@SQLCMD)
		--
		SET @SQLCMD = 'ALTER DATABASE [$(CMS_DATABASE)] SET RECOVERY SIMPLE'
		--PRINT @SQLCMD
		EXEC(@SQLCMD)	
		--
		SET @SQLCMD = 'ALTER DATABASE [$(CMS_DATABASE)] SET PAGE_VERIFY CHECKSUM'
		--PRINT @SQLCMD
		EXEC(@SQLCMD)	
	
			PRINT '////////////////////////////////////////////////////////'
			PRINT 'Database [$(CMS_DATABASE)] created successfully  - '+CONVERT(VARCHAR,GETDATE(), 21)
			PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
	END TRY
		BEGIN CATCH
				SELECT ERROR_MESSAGE() AS ErrorMessage;
				PRINT 'An issue was encountered during [$(CMS_DATABASE)] database creation.  Deployment halted.'
				SET NOEXEC ON
		END CATCH
ELSE
	BEGIN
			PRINT 'Found database [$(CMS_DATABASE)].  Deployment continuing.'
	END
GO
-- ===============================================================================================
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerStigScan database object deployment start - '+CONVERT(VARCHAR,GETDATE(), 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
-- ===============================================================================================
USE [$(CMS_DATABASE)]
GO
-- ===============================================================================================
-- Create schema
-- ===============================================================================================
--
PRINT 'Begin create schema'
:setvar CREATE_SCHEMA "PowerSTIG"
--
PRINT '		Create schema: $(CREATE_SCHEMA)'
--
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'PowerSTIG')
	EXEC('CREATE SCHEMA [PowerSTIG] AUTHORIZATION [dbo]');	
GO
PRINT 'End create schema'

-- ===============================================================================================
-- Create objects needed for deployment logging
-- ===============================================================================================
PRINT 'Begin create logging objects'
--
:setvar DROP_TABLE "ScanLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanLog') IS NOT NULL
	DROP TABLE PowerSTIG.ScanLog
GO
:setvar CREATE_TABLE "ScanLog"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ScanLog (
	LogTS datetime NOT NULL DEFAULT(GETDATE()),
	LogEntryTitle varchar(128) NULL,
	LogMessage varchar(2000) NULL,
	ActionTaken varchar(25) NULL CONSTRAINT check_ActionTaken CHECK (ActionTaken IN ('INSERT','UPDATE','DELETE','DEPLOY','ERROR','START','FINISH')),
	LoggedUser varchar(50) NULL DEFAULT(SUSER_NAME()))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
:setvar DROP_PROC "sproc_InsertScanLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertScanLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertScanLog
	--
GO
:setvar CREATE_PROC "sproc_InsertScanLog"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_InsertScanLog
			@LogEntryTitle varchar(128)=NULL,
			@LogMessage varchar(1000)=NULL,
			@ActionTaken varchar(25)=NULL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @LoggedUser varchar(50)
DECLARE @LogTS datetime
SET @LoggedUser = (SELECT SUSER_NAME() AS LoggedUser)
SET @LogTS = (SELECT GETDATE() AS LogTS)
--
	BEGIN TRY
		INSERT INTO	
			PowerSTIG.ScanLog (LogTS,LogEntryTitle,LogMessage,ActionTaken,LoggedUser)
		VALUES
			(
			@LogTS,
			@LogEntryTitle,
			@LogMessage,
			@ActionTaken,
			@LoggedUser
			)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
PRINT 'End create logging objects'
-- ===============================================================================================
-- Drop constraints
-- ===============================================================================================
PRINT 'Begin drop constraints'
--

:setvar DROP_CONSTRAINT "FK_FindingRepo_ComplianceType"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_ComplianceType]
GO
--
:setvar DROP_CONSTRAINT "FK_FindingRepo_TargetComputer"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_TargetComputer]
GO
--
:setvar DROP_CONSTRAINT "FK_TargetComputer"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[TargetTypeMap] DROP CONSTRAINT [FK_TargetComputer]
GO
--
:setvar DROP_CONSTRAINT "FK_ComplianceType"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[TargetTypeMap] DROP CONSTRAINT [FK_ComplianceType]
GO
--
:setvar DROP_CONSTRAINT "FK_FindingRepo_FindingCategory"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_FindingCategory', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_FindingCategory]
GO
--
:setvar DROP_CONSTRAINT "FK_ComplianceCheckLog_TargetComputer"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_ComplianceCheckLog_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[ComplianceCheckLog] DROP CONSTRAINT [FK_ComplianceCheckLog_TargetComputer]
GO
--
:setvar DROP_CONSTRAINT "FK_FindingRepo_Finding"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_Finding', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_Finding]
GO
--
:setvar DROP_CONSTRAINT "FK_ComplianceCheckLog_ComplianceType"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_ComplianceCheckLog_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[ComplianceCheckLog] DROP CONSTRAINT [FK_ComplianceCheckLog_ComplianceType]
GO
--
PRINT 'End drop constraints'
-- ===============================================================================================
-- Drop tables
-- ===============================================================================================
PRINT 'Begin drop tables'
--
:setvar DROP_TABLE "TargetTypeMap"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.TargetTypeMap') IS NOT NULL
	DROP TABLE PowerSTIG.TargetTypeMap
GO
--
:setvar DROP_TABLE "ComplianceTypes"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceTypes') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceTypes
GO
:setvar DROP_TABLE "ComplianceTargets"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceTargets') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceTargets
GO
:setvar DROP_TABLE "ComplianceIteration"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceIteration') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceIteration
GO
:setvar DROP_TABLE "FindingImport"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingImport') IS NOT NULL
	DROP TABLE PowerSTIG.FindingImport
GO
:setvar DROP_TABLE "UnreachableTargets"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.UnreachableTargets') IS NOT NULL
	DROP TABLE PowerSTIG.UnreachableTargets
GO
:setvar DROP_TABLE "FindingImportFiles"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingImportFiles') IS NOT NULL
	DROP TABLE PowerSTIG.FindingImportFiles
GO
:setvar DROP_TABLE "ComplianceCheckLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceCheckLog') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceCheckLog
GO
:setvar DROP_TABLE "FindingRepo"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingRepo') IS NOT NULL
	DROP TABLE PowerSTIG.FindingRepo
GO
:setvar DROP_TABLE "DupFindingFileCheck"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.DupFindingFileCheck') IS NOT NULL
	DROP TABLE PowerSTIG.DupFindingFileCheck
GO
:setvar DROP_TABLE "FindingSubPlatform"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingSubPlatform') IS NOT NULL
	DROP TABLE PowerSTIG.FindingSubPlatform
GO
:setvar DROP_TABLE "ScanImportLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanImportLog') IS NOT NULL
	DROP TABLE PowerSTIG.ScanImportLog
GO
--:setvar DROP_TABLE "ScanLog"
--PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
--IF OBJECT_ID('PowerSTIG.ScanLog') IS NOT NULL
--	DROP TABLE PowerSTIG.ScanLog
--GO
:setvar DROP_TABLE "ScanImportErrorLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanImportErrorLog') IS NOT NULL
	DROP TABLE PowerSTIG.ScanImportErrorLog
GO
:setvar DROP_TABLE "ScanQueue"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerStig.ScanQueue') IS NOT NULL
	DROP TABLE PowerStig.ScanQueue
GO
:setvar DROP_TABLE "FindingCategory"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingCategory') IS NOT NULL
	DROP TABLE PowerSTIG.FindingCategory
GO
:setvar DROP_TABLE "FindingSeverity"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingSeverity') IS NOT NULL
	DROP TABLE PowerSTIG.FindingSeverity
GO
:setvar DROP_TABLE "ComplianceConfig"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion')AS smallint)) >= 13
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd =' 
		IF OBJECT_ID (''PowerSTIG.ComplianceConfig'') IS NOT NULL
			BEGIN
				ALTER TABLE [PowerSTIG].[ComplianceConfig] SET ( SYSTEM_VERSIONING = OFF)
				DROP TABLE PowerSTIG.ComplianceConfigHistory
			END'
		EXEC(@SQLcmd)
	END
GO
IF OBJECT_ID('PowerSTIG.ComplianceConfig') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceConfig
GO
:setvar DROP_TABLE "Finding"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.Finding') IS NOT NULL
	DROP TABLE PowerSTIG.Finding
GO
:setvar DROP_TABLE "Scans"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.Scans') IS NOT NULL
	DROP TABLE PowerSTIG.Scans
GO
:setvar DROP_TABLE "MemberServerSTIG"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.MemberServerSTIG') IS NOT NULL
	DROP TABLE PowerSTIG.MemberServerSTIG
GO
:setvar DROP_TABLE "PowerSTIG.OrgSettingsRepo"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.OrgSettingsRepo') IS NOT NULL
	DROP TABLE PowerSTIG.OrgSettingsRepo
GO
:setvar DROP_TABLE "PowerSTIG.FireFoxSTIG"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FireFoxSTIG') IS NOT NULL
	DROP TABLE PowerSTIG.FireFoxSTIG
GO
:setvar DROP_TABLE "PowerSTIG.AdminFunction"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.AdminFunction') IS NOT NULL
	DROP TABLE PowerSTIG.AdminFunction
GO
:setvar DROP_TABLE "PowerSTIG.AdminFunctionUsers"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.AdminFunctionUsers') IS NOT NULL
	DROP TABLE PowerSTIG.AdminFunctionUsers
GO
:setvar DROP_TABLE "PowerSTIG.AdminFunctionsMap"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.AdminFunctionsMap') IS NOT NULL
	DROP TABLE PowerSTIG.AdminFunctionsMap
GO
:setvar DROP_TABLE "PowerSTIG.StigText"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.StigText') IS NOT NULL
	DROP TABLE PowerSTIG.StigText
GO
:setvar DROP_TABLE "PowerSTIG.StigTextRepo"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.StigTextRepo') IS NOT NULL
	DROP TABLE PowerSTIG.StigTextRepo
GO
:setvar DROP_TABLE "PowerSTIG.ScanSource"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanSource') IS NOT NULL
	DROP TABLE PowerSTIG.ScanSource
GO
:setvar DROP_TABLE "PowerSTIG.TargetTypeOS"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.TargetTypeOS') IS NOT NULL
	DROP TABLE PowerSTIG.TargetTypeOS
GO
:setvar DROP_TABLE "PowerSTIG.ComplianceTypesInfo"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceTypesInfo') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceTypesInfo
GO
:setvar DROP_TABLE "PowerSTIG.RSpages"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.RSpages') IS NOT NULL
	DROP TABLE PowerSTIG.RSpages
GO
--
PRINT 'End drop tables'
GO
-- ===============================================================================================
-- Drop views
-- ===============================================================================================
PRINT 'Begin drop views'
GO
:setvar DROP_VIEW "vw_TargetTypeMap"
PRINT '		Drop view: $(CREATE_SCHEMA).$(DROP_VIEW)'
IF OBJECT_ID('PowerSTIG.vw_TargetTypeMap') IS NOT NULL
	DROP VIEW PowerSTIG.vw_TargetTypeMap
GO
:setvar DROP_VIEW "v_BulkFindingImport"
PRINT '		Drop view: $(CREATE_SCHEMA).$(DROP_VIEW)'
IF OBJECT_ID('PowerSTIG.v_BulkFindingImport') IS NOT NULL
	DROP VIEW PowerSTIG.v_BulkFindingImport
PRINT 'End drop views'
-- ===============================================================================================
-- Create tables
-- ===============================================================================================
PRINT 'Begin create tables'
----

GO
--
:setvar CREATE_TABLE "Scans"
--  
CREATE TABLE PowerSTIG.Scans (
	[ScanID] [int] IDENTITY(1,1) NOT NULL,
	[ScanGUID] [char](36) NOT NULL,
	[ScanSourceID] smallint NOT NULL,
	[ScanDate] [datetime] NOT NULL,
    [ScanVersion] varchar(8) NULL,
	[isProcessed] [bit] NOT NULL DEFAULT(0))
--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  

GO
--
:setvar CREATE_TABLE "FindingSeverity"
--  
CREATE TABLE [PowerSTIG].[FindingSeverity](
	[FindingSeverityID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[FindingSeverity] [varchar](128) NOT NULL)
--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO  

--
:setvar CREATE_TABLE "FindingCategory"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.FindingCategory(
	FindingCategoryID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FindingCategory varchar(128) NOT NULL)
--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO  
--
:setvar CREATE_TABLE "Finding"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.Finding(
	FindingID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	Finding varchar(128) NOT NULL,
	FindingText varchar(768) NULL)
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO
--
:setvar CREATE_TABLE "ComplianceTargets"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
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
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO
--
:setvar CREATE_TABLE "ComplianceTypes"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ComplianceTypes (
	ComplianceTypeID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ComplianceType varchar(256) NOT NULL UNIQUE,
	isActive BIT NOT NULL DEFAULT(1))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO

--
:setvar CREATE_TABLE "ComplianceCheckLog"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ComplianceCheckLog(
	CheckLogID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	--IterationID INT NOT NULL,
	ScanID INT NOT NULL,
	TargetComputerID INT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	LastComplianceCheck datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO
--
:setvar CREATE_TABLE "FindingRepo"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.FindingRepo(
	[TargetComputerID] [int] NOT NULL,
	[FindingID] [int] NOT NULL,
	[InDesiredState] [bit] NOT NULL,
	[ComplianceTypeID] [int] NOT NULL,
	[ScanID] [int] NOT NULL)
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "ScanQueue"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerStig.ScanQueue (
	ScanQueueID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputer varchar(256) NOT NULL,
	ComplianceType varchar(256) NOT NULL,
	QueueStart datetime NOT NULL,
	QueueEnd datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "ComplianceConfig"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion')AS smallint)) >= 13
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd ='
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
				)'
		EXEC (@SQLcmd)
	END
GO
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion') AS smallint)) <= 12
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd ='
		CREATE TABLE PowerSTIG.ComplianceConfig (
			ConfigID SMALLINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
			ConfigProperty varchar(256) NOT NULL,
			ConfigSetting varchar(256) NOT NULL,
			ConfigNote varchar(1000) NULL)'
		EXEC (@SQLcmd)
	END
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
/*
--
:setvar CREATE_TABLE "TargetTypeMap"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.TargetTypeMap (
	TargetTypeMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputerID INT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	isRequired BIT NOT NULL)
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
*/
--
:setvar CREATE_TABLE "FindingImport"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
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
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "AdminFunction"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE PowerSTIG.AdminFunction (
	FunctionID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FunctionName varchar(128) NOT NULL UNIQUE,
	FunctionDescription varchar(768) NOT NULL DEFAULT('No function description specified.'),
	FunctionPage varchar(128) NULL,
	isActive BIT NOT NULL DEFAULT(0))
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "AdminFunctionUsers"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE PowerSTIG.AdminFunctionUsers (
AdminID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
FQDNandAdmin varchar(256) NOT NULL UNIQUE)
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "AdminFunctionsMap"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE PowerSTIG.AdminFunctionsMap (
FunctionMapID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
FunctionID smallint NOT NULL,
AdminID smallint NOT NULL,
isActive BIT NOT NULL DEFAULT(1))
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "StigTextRepo"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE [PowerSTIG].[StigTextRepo](
	[TextID] [int] IDENTITY(1,1) NOT NULL,
	[RuleID] [nvarchar](25) NOT NULL,
	[Severity] [nvarchar](25) NOT NULL,
	[Title] [nvarchar](1000) NOT NULL,
	[DSCresource] [nvarchar](256) NOT NULL,
	[RawString] [nvarchar](max) NOT NULL)
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 	
GO
--
:setvar CREATE_TABLE "ScanSource"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE PowerSTIG.ScanSource (
			ScanSourceID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
			ScanSource varchar(25) NOT NULL UNIQUE)
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 	
GO
--
:setvar CREATE_TABLE "TargetTypeOS"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE PowerSTIG.TargetTypeOS(
        OSid smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
        OSname varchar(256) NOT NULL UNIQUE)
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 	
GO
--
:setvar CREATE_TABLE "OrgSettingsRepo"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
CREATE TABLE PowerSTIG.OrgSettingsRepo (
    OrgRepoID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    TypesInfoID INT NOT NULL,
    Finding varchar(128) NULL,
    OrgValue varchar(4000)NULL)
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 	
GO
--
:setvar CREATE_TABLE "ComplianceTypesInfo"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
--
CREATE TABLE PowerSTIG.ComplianceTypesInfo (
	TypesInfoID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ComplianceTypeID INT NOT NULL,
	OSid smallint NOT NULL DEFAULT(0),
	OrgValue varchar(10),
	OrgSettingAlias varchar(128) NOT NULL,
	OrgSettingFile varchar(256) NOT NULL)
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 	
GO
--
:setvar CREATE_TABLE "RSpages"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
GO
--
CREATE TABLE PowerSTIG.RSpages (
    RSpageID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
    PageName varchar(256) NOT NULL UNIQUE,
    ReportName varchar(256) NOT NULL UNIQUE,
    PageDescription varchar(512) NULL,
    ReportOrder smallint NOT NULL DEFAULT(2),
    isActive BIT NOT NULL DEFAULT(1))
    --
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 	
GO
PRINT 'End create tables'
-- ===============================================================================================
-- Create views
-- ===============================================================================================
--PRINT 'Begin create views'
--GO
--:setvar CREATE_VIEW "vw_TargetTypeMap"
----
--PRINT '		Create view: $(CREATE_SCHEMA).$(CREATE_VIEW)'
--GO
--CREATE VIEW PowerSTIG.vw_TargetTypeMap
--AS
----------------------------------------------------------------------------------- 
---- The sample scripts are not supported under any Microsoft standard support 
---- program or service. The sample scripts are provided AS IS without warranty  
---- of any kind. Microsoft further disclaims all implied warranties including,  
---- without limitation, any implied warranties of merchantability or of fitness for 
---- a particular purpose. The entire risk arising out of the use or performance of  
---- the sample scripts and documentation remains with you. In no event shall 
---- Microsoft, its authors, or anyone else involved in the creation, production, or 
---- delivery of the scripts be liable for any damages whatsoever (including, 
---- without limitation, damages for loss of business profits, business interruption, 
---- loss of business information, or other pecuniary loss) arising out of the use 
---- of or inability to use the sample scripts or documentation, even if Microsoft 
---- has been advised of the possibility of such damages 
-----------------------------------------------------------------------------------
---- ===============================================================================================
---- Purpose:
---- Revisions:
---- 1112018 - Kevin Barlett, Microsoft - Initial creation.
---- ===============================================================================================
--	SELECT
--		T.TargetComputer,
--		C.ComplianceType
--	FROM
--		PowerSTIG.TargetTypeMap M
--			JOIN PowerSTIG.ComplianceTargets T
--				ON M.TargetComputerID = T.TargetComputerID
--			JOIN PowerSTIG.ComplianceTypes C
--				ON M.ComplianceTypeID = C.ComplianceTypeID
--	WHERE
--		isRequired = 1
--GO
--	--
--	EXEC sys.sp_addextendedproperty   
--	@name = N'DEP_VER',   
--	@value = '$(DEP_VER)',  
--	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
--	@level1type = N'VIEW',  @level1name = '$(CREATE_VIEW)'; 
--GO
--PRINT 'End create views'
--GO

-- ===============================================================================================
-- Hydrate ComplianceConfig table
-- ===============================================================================================
PRINT 'Hydrating PowerSTIG.ComplianceConfig table'
--
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('FindingRepoTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckAlert','OFF','Possible values are ON or OFF.  Controls whether the last compliance type checks for a target computer has violated the LastComplianceCheckInDays threshold.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckInDays','90','Specifies the number of days that a compliance type check for a target computer may not occur.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckAlertRecipients','user@mail.mil',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ComplianceCheckLogTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('FindingImportFilesTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('MailProfileName','$(MAIL_PROFILE)',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('CKLfileLoc','$(CKL_OUTPUT)',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('CKLfileArchiveLoc','$(CKL_ARCHIVE)',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanImportLogRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanImportErrorLogRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ConcurrentScans','5','This setting controls the maximum number of simultaneous scans.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanLogRetentionDays','730','This setting controls the number of days of history to store in the PowerSTIG.ScanLog table.')
    INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ORGsettingXML','$(ORG_SETTING_XML)','This setting sets the location of the PowerStig ORG setting XML files.')
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
-- Hydrate TargetTypeOS
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
--:setvar CREATE_CONSTRAINT "FK_TargetComputer"
--PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
--ALTER TABLE PowerSTIG.TargetTypeMap WITH NOCHECK ADD  CONSTRAINT [FK_TargetComputer]
--	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
--GO
----
--:setvar CREATE_CONSTRAINT "FK_ComplianceType"
--PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
--ALTER TABLE PowerSTIG.TargetTypeMap WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceType]
--	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
GO
--
:setvar CREATE_CONSTRAINT "FK_FindingRepo_TargetComputer"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
GO
--
:setvar CREATE_CONSTRAINT "FK_FindingRepo_ComplianceType"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
GO

--
:setvar CREATE_CONSTRAINT "FK_ComplianceCheckLog_TargetComputer"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.ComplianceCheckLog WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceCheckLog_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
GO
--
:setvar CREATE_CONSTRAINT "FK_ComplianceCheckLog_ComplianceType"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.ComplianceCheckLog WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceCheckLog_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
GO
--
:setvar CREATE_CONSTRAINT "FK_FindingRepo_Finding"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_Finding]
	FOREIGN KEY (FindingID) REFERENCES [PowerSTIG].[Finding] (FindingID)
GO
--
PRINT 'End create constraints'
GO

-- ===============================================================================================
-- Indexes
-- ===============================================================================================
PRINT 'Begin create indexes'
--
:setvar CREATE_INDEX "IX_UNQ_ConfigProperty"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_ConfigProperty')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_ConfigProperty ON PowerSTIG.ComplianceConfig(ConfigProperty)
GO
:setvar CREATE_INDEX "IX_UNQ_FunctionAdmin"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_FunctionAdmin')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_FunctionAdmin ON PowerSTIG.AdminFunctionsMap (FunctionID,AdminID)
GO
--:setvar CREATE_INDEX "IX_UNQ_ComputerAndTypeID"
--PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
--IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_ComputerAndTypeID')
--	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_ComputerAndTypeID ON PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID)
GO
:setvar CREATE_INDEX "IX_TargetComplianceCheck"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_TargetComplianceCheck')
	--DROP INDEX [IX_TargetComplianceCheck] ON [PowerSTIG].[ComplianceCheckLog]
	CREATE NONCLUSTERED INDEX [IX_TargetComplianceCheck]
		ON PowerSTIG.ComplianceCheckLog(TargetComputerID,ComplianceTypeID,LastComplianceCheck)
GO
/*
:setvar CREATE_INDEX "IX_CoverRepo"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_CoverRepo')
	--DROP INDEX [IX_CoverRepo] ON [PowerSTIG].[FindingRepo]
	CREATE NONCLUSTERED INDEX IX_CoverRepo 
		ON PowerSTIG.FindingRepo(TargetComputerID) INCLUDE (FindingID,InDesiredState,ComplianceTypeID,ScanID,ScanSourceID)
GO
*/
:setvar CREATE_INDEX "IX_UNQ_OrgSettingsRepo"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_OrgSettingsRepo')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_OrgSettingsRepo ON PowerSTIG.OrgSettingsRepo (TypesInfoID,Finding)
GO
:setvar CREATE_INDEX "IX_UNQ_Repo"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_Repo')
CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_Repo ON PowerSTIG.FindingRepo (TargetComputerID,FindingID,ComplianceTypeID,ScanID)

GO
PRINT 'End create indexes'
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
-- Stored procedure drop and create starts
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
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
PRINT 'Begin drop procedures'
--
:setvar DROP_PROC "sproc_GetAllServersRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetAllServersRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetAllServersRoles
	--
GO
:setvar DROP_PROC "sproc_GetInactiveServersRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetInactiveServersRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetInactiveServersRoles
	--
GO
:setvar DROP_PROC "sproc_GetActiveRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetActiveRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetActiveRoles
	--
GO
:setvar DROP_PROC "sproc_UpdateServerRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateServerRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateServerRoles
	--
GO
:setvar DROP_PROC "sproc_GetRolesPerServer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetRolesPerServer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetRolesPerServer
	--
GO
:setvar DROP_PROC "sproc_GetActiveServers"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetActiveServers') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetActiveServers
	--
GO
:setvar DROP_PROC "sproc_GetReachableTargets"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetReachableTargets') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetReachableTargets
	--
GO
:setvar DROP_PROC "sproc_ProcessRawInput"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_ProcessRawInput') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_ProcessRawInput
	--
GO
:setvar DROP_PROC "sproc_CreateComplianceIteration"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_CreateComplianceIteration') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_CreateComplianceIteration
	--
GO
:setvar DROP_PROC "sproc_CompleteComplianceIteration"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_CompleteComplianceIteration') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_CompleteComplianceIteration
	--
GO
:setvar DROP_PROC "GetComplianceStateByServer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.GetComplianceStateByServer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.GetComplianceStateByServer
	--
GO
:setvar DROP_PROC "sproc_GetComplianceStateByServer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetComplianceStateByServer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetComplianceStateByServer
GO
:setvar DROP_PROC "sproc_InsertUnreachableTargets"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertUnreachableTargets') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertUnreachableTargets
	--
GO
:setvar DROP_PROC "InsertFindingFileImport"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.InsertFindingFileImport') IS NOT NULL
	DROP PROCEDURE PowerSTIG.InsertFindingFileImport
	--
GO
:setvar DROP_PROC "sproc_GetUnprocessedFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetUnprocessedFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetUnprocessedFiles
	--
GO
:setvar DROP_PROC "sproc_UpdateFindingImportFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateFindingImportFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateFindingImportFiles
	--
GO
:setvar DROP_PROC "sproc_InsertComplianceCheckLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertComplianceCheckLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertComplianceCheckLog
	--
GO
:setvar DROP_PROC "sproc_DuplicateFileCheck"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_DuplicateFileCheck') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_DuplicateFileCheck
	--
GO
:setvar DROP_PROC "sproc_GetDuplicateFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetDuplicateFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetDuplicateFiles
	--
GO
:setvar DROP_PROC "sproc_GetConfigSetting"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetConfigSetting') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetConfigSetting
	--
GO
:setvar DROP_PROC "sproc_AssociateFileIDtoData"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AssociateFileIDtoData') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AssociateFileIDtoData
	--
GO
:setvar DROP_PROC "sproc_AssociateFileToTarget"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AssociateFileToTarget') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AssociateFileToTarget
	--
GO
:setvar DROP_PROC "sproc_GetFilesToCompress"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetFilesToCompress') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetFilesToCompress
	--
GO
:setvar DROP_PROC "sproc_GetTargetsWithFilesToCompress"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetTargetsWithFilesToCompress') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetTargetsWithFilesToCompress
	--
GO
:setvar DROP_PROC "sproc_AddTargetComputer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AddTargetComputer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AddTargetComputer
	--
GO
:setvar DROP_PROC "sproc_GetFullyProcessedFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetFullyProcessedFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetFullyProcessedFiles
	--
GO
:setvar DROP_PROC "sproc_PurgeHistory"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_PurgeHistory') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_PurgeHistory
	--
GO
:setvar DROP_PROC "sproc_GetLastComplianceCheckByTarget"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetLastComplianceCheckByTarget') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTarget
	--
GO
:setvar DROP_PROC "sproc_GetLastComplianceCheckByTargetAndRole"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole
	--
GO
:setvar DROP_PROC "sproc_DuplicateFileAlert"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_DuplicateFileAlert') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_DuplicateFileAlert
	--
GO
:setvar DROP_PROC "sproc_UpdateConfig"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateConfig') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateConfig
	--
GO
:setvar DROP_PROC "sproc_InsertConfig"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertConfig') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertConfig
	--
GO
:setvar DROP_PROC "sproc_InsertScanErrorLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertScanErrorLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertScanErrorLog
	--
GO
--:setvar DROP_PROC "sproc_InsertScanLog"
--PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
--IF OBJECT_ID('PowerSTIG.sproc_InsertScanLog') IS NOT NULL
--	DROP PROCEDURE PowerSTIG.sproc_InsertScanLog
--	--
--GO
:setvar DROP_PROC "sproc_GetScanQueue"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetScanQueue') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetScanQueue
	--
GO
:setvar DROP_PROC "sproc_GetLastDataForCKL"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetLastDataForCKL') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetLastDataForCKL
	--
GO
:setvar DROP_PROC "sproc_GetIterationID"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetIterationID') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetIterationID
	--
GO
:setvar DROP_PROC "sproc_DeleteTargetComputerAndData"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_DeleteTargetComputerAndData') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_DeleteTargetComputerAndData
	--
GO
:setvar DROP_PROC "sproc_InsertFindingImport"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertFindingImport') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertFindingImport
	--
GO
:setvar DROP_PROC "sproc_ProcessFindings"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_ProcessFindings') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_ProcessFindings
	--
GO
:setvar DROP_PROC "sproc_GetDependencies"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetDependencies') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetDependencies 
GO
:setvar DROP_PROC "sproc_ConsumeStigJson"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_ConsumeStigJson') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_ConsumeStigJson
	--
GO
:setvar DROP_PROC "sproc_GetScanLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetScanLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetScanLog
	--
GO
:setvar DROP_PROC "sproc_ImportSTIGxml"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_ImportSTIGxml') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_ImportSTIGxml
	--
GO
:setvar DROP_PROC "sproc_GetCountServers"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetCountServers') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetCountServers
GO
:setvar DROP_PROC "sproc_GetComplianceStateByRole"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetComplianceStateByRole') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetComplianceStateByRole
GO
:setvar DROP_PROC "sproc_InitiateManualScan"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InitiateManualScan') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InitiateManualScan
GO
:setvar DROP_PROC "sproc_GetTargetComplianceTypeLastCheck"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetTargetComplianceTypeLastCheck') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetTargetComplianceTypeLastCheck
GO
:setvar DROP_PROC "sproc_TargetRoleScanDash"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_TargetRoleScanDash') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_TargetRoleScanDash
GO
:setvar DROP_PROC "sproc_GenerateDates"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GenerateDates') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GenerateDates
GO
:setvar DROP_PROC "sproc_GetAdminFunction"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetAdminFunction') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetAdminFunction
GO
:setvar DROP_PROC "sproc_GetComplianceStats"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetComplianceStats') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetComplianceStats
GO
:setvar DROP_PROC "sproc_GetStigTextByTargetScanCompliance"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetStigTextByTargetScanCompliance') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetStigTextByTargetScanCompliance
GO
:setvar DROP_PROC "sproc_UpdateTargetOS"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateTargetOS') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateTargetOS
GO
:setvar DROP_PROC "sproc_GetQueuedScans"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetQueuedScans') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetQueuedScans
GO
:setvar DROP_PROC "sproc_ImportOrgSettingsXML"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_ImportOrgSettingsXML') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_ImportOrgSettingsXML
GO
:setvar DROP_PROC "sproc_GenerateORGxml"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GenerateORGxml') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GenerateORGxml
GO
:setvar DROP_PROC "sproc_InsertNewScan"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertNewScan') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertNewScan
GO
:setvar DROP_PROC "sproc_AddOrgSetting"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AddOrgSetting') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AddOrgSetting
GO
:setvar DROP_PROC "sproc_ResetTargetRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_ResetTargetRoles') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_ResetTargetRoles
GO
:setvar DROP_PROC "sproc_GetActiveServersRoleCount"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetActiveServersRoleCount') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetActiveServersRoleCount
GO
:setvar DROP_PROC "sproc_ComplianceTrendByTargetRole"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_ComplianceTrendByTargetRole') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_ComplianceTrendByTargetRole
GO
:setvar DROP_PROC "sproc_GetComplianceTypes"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetComplianceTypes') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetComplianceTypes
GO
:setvar DROP_PROC "sproc_GetOrgSettingsByRole"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetOrgSettingsByRole') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetOrgSettingsByRole
GO
:setvar DROP_PROC "sproc_GetRSpages"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetRSpages') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetRSpages 
GO
:setvar DROP_PROC "sproc_GetLogDates"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetLogDates') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetLogDates 
GO
:setvar DROP_PROC "sproc_GetDetailedScanResults"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetDetailedScanResults') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetDetailedScanResults 
GO
:setvar DROP_PROC "sproc_UpdateCKLtargetInfo"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_UpdateCKLtargetInfo') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_UpdateCKLtargetInfo 
GO
:setvar DROP_PROC "sproc_GetCKLtargetInfo"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerStig.sproc_GetCKLtargetInfo') IS NOT NULL
	DROP PROCEDURE PowerStig.sproc_GetCKLtargetInfo 
GO    
PRINT 'End drop procedures'
GO
PRINT 'Start create procedures'
GO
/*
-- ==================================================================
-- sproc_GetAllServersRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_GetAllServersRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetAllServersRoles AS
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Query for all servers - Return Name/Roles
-- EXAMPLE: EXEC PowerSTIG.sproc_GetAllServersRoles
	SELECT DISTINCT
		T.TargetComputer,
		Y.ComplianceType
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 1
		AND
		T.isActive = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO

-- ==================================================================
-- sproc_GetInactiveServersRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_GetInactiveServersRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetInactiveServersRoles AS
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Query for all inactive - Return Name/Roles where active == 0 - Don't Return where active == 1
-- EXAMPLE: EXEC PowerSTIG.sproc_GetInactiveServersRoles
	SELECT DISTINCT
		T.TargetComputer,
		Y.ComplianceType
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 0
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO

-- ==================================================================
-- sproc_GetActiveRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_GetActiveRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetActiveRoles
			@ComplianceType varchar(256)
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Query by role Return Name/Roles where specified role/roles == 1
-- EXAMPLE: EXEC PowerSTIG.sproc_GetActiveRoles @ComplianceType = 'DNScheck'
	SELECT DISTINCT
		T.TargetComputer
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		Y.ComplianceType = @ComplianceType
		AND
		M.isRequired = 1
		AND
		T.isActive = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- sproc_UpdateServerRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_UpdateServerRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_UpdateServerRoles
				@TargetComputer varchar(256),
				@ComplianceType varchar(256),
				@UpdateAction BIT --1 = Enable, 0 = Disable
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
DECLARE @TargetComputerID INT
DECLARE @ComplianceTypeID INT
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = LTRIM(RTRIM(@ComplianceType)))
--SET @StepMessage = ('Target type map update to ['+@TargetComputer+'] requested by ['+SUSER_NAME()+'].  The UpdateAction is ['+CAST(@UpdateAction AS char(2))+'].')
--
SET @StepName = 'Update TargetTypeMap'

--
-- Invalid TargetComputer specified
-- 
	IF @TargetComputerID IS NULL
		BEGIN
			SET @StepMessage = 'The specified target computer ['+LTRIM(RTRIM(@TargetComputer))+'] was not found.  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			
			RETURN
		END
--
-- Invalid ComplianceType specified
--

	IF @ComplianceTypeID IS NULL
		BEGIN
			SET @StepMessage = 'The specified compliance type ['+LTRIM(RTRIM(@ComplianceType))+'] was not found.  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
		END
--
	BEGIN TRY
			UPDATE
					PowerSTIG.TargetTypeMap
				SET
					isRequired = @UpdateAction
				FROM
					PowerSTIG.ComplianceTargets T
						JOIN PowerSTIG.TargetTypeMap M
							ON T.TargetComputerID = M.TargetComputerID
						JOIN PowerSTIG.ComplianceTypes Y
							ON M.ComplianceTypeID = Y.ComplianceTypeID
				WHERE
					T.TargetComputerID = @TargetComputerID
					AND
					Y.ComplianceTypeID = @ComplianceTypeID 
		--
		-- Log the update
		--
		SET @StepMessage = ('Target type map update to ['+@TargetComputer+'] requested by ['+SUSER_NAME()+'].  The UpdateAction is ['+CAST(@UpdateAction AS char(2))+'].')
		SET @StepAction = 'UPDATE'
		EXEC PowerSTIG.sproc_InsertScanLog
		   @LogEntryTitle = @StepName
		   ,@LogMessage = @StepMessage
		   ,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- sproc_GetRolesPerServer
-- ==================================================================
:setvar CREATE_PROC "sproc_GetRolesPerServer"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE [PowerSTIG].[sproc_GetRolesPerServer] 
				@TargetComputer varchar(256)
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- 04222019 - Kevin Barlett, Microsoft - SCAP+PowerSTIG integration support modifications.
-- USE EXAMPLE:
-- EXEC PowerSTIG.sproc_GetRolesPerServer @TargetComputer = 'SQLtest003'
-- ===============================================================================================
--Query roles for a specific Target Computer
DECLARE @TargetComputerID INT
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
	--
	SELECT DISTINCT
		Y.ComplianceType
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
			JOIN PowerSTIG.TargetTypeOS O
				ON O.OSid = T.OSid
	WHERE
		M.isRequired = 1
		AND
		T.isActive = 1
		AND
		O.OSname NOT IN ('2016')
		AND
		Y.ComplianceType != 'WindowsServerDC'
		AND
		T.TargetComputerID = @TargetComputerID
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO 
*/
-- ==================================================================
-- sproc_GetActiveServers
-- ==================================================================
:setvar CREATE_PROC "sproc_GetActiveServers"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE [PowerSTIG].[sproc_GetActiveServers] 
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	SELECT DISTINCT
		TargetComputer
	FROM
		PowerSTIG.ComplianceTargets T
	WHERE
		T.isActive = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO 
/*
-- ==================================================================
-- sproc_GetComplianceStateByServer
-- ==================================================================
:setvar CREATE_PROC "sproc_GetComplianceStateByServer"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetComplianceStateByServer
				@TargetComputer varchar(255),
				@GUID char(36),
                @ScanSource varchar(25)
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- 04102019 - Kevin Barlett, Microsoft - Modifications for SCAP + PowerSTIG integration.
-- ===============================================================================================
	SET NOCOUNT ON
	--
	DECLARE @TargetComputerID INT
	DECLARE @ScanID INT
	DECLARE @ScanSourceID smallint
	SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
	SET @ScanID = (SELECT ScanID FROM PowerSTIG.Scans WHERE ScanGUID = @GUID)
	SET @ScanSourceID = (SELECT ScanSourceID FROM PowerSTIG.ScanSource WHERE ScanSource = @ScanSource)
-- =======================================================
-- Retrieve findings
-- =======================================================
		SELECT
			DISTINCT (F.Finding),
			R.InDesiredState
		FROM
			PowerSTIG.FindingRepo R
				JOIN
					PowerSTIG.Finding F
						ON R.FindingID = F.FindingID
				JOIN
					PowerSTIG.ScanSource S
						ON S.ScanSourceID = R.ScanSourceID
		WHERE
			R.TargetComputerID = @TargetComputerID 
			AND
			R.ScanID = @ScanID
			AND
			R.ScanSourceID = @ScanSourceID
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
*/
-- ==================================================================
-- sproc_GetConfigSetting
-- ==================================================================
:setvar CREATE_PROC "sproc_GetConfigSetting"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetConfigSetting 
					@ConfigProperty varchar(255)
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
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
SET NOCOUNT ON
--
	SELECT ConfigSetting = 
		CASE
			WHEN LTRIM(RTRIM(ConfigSetting)) = '' THEN 'No value specified for supplied ConfigProperty.'
			WHEN ConfigSetting IS NULL THEN 'No value specified for supplied ConfigProperty.'
		ELSE LTRIM(RTRIM(ConfigSetting))
		END
	FROM
		PowerSTIG.ComplianceConfig
	WHERE
		ConfigProperty = @ConfigProperty
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_AddTargetComputer
-- ==================================================================
:setvar CREATE_PROC "sproc_AddTargetComputer"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
IF OBJECT_ID('PowerSTIG.sproc_AddTargetComputer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AddTargetComputer
GO
CREATE PROCEDURE PowerSTIG.sproc_AddTargetComputer
					@TargetComputerName varchar(MAX) NULL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- 07162018 - Kevin Barlett, Microsoft - Additions and changes to support PowerSTIG V2.
-- 04122019 - Kevin Barlett, Microsoft - Standardization of compliance types.
-- Use examples:
-- EXEC PowerSTIG.sproc_AddTargetComputer @TargetComputerName = 'ThisIsATargetComputer, AndAnotherComputer, ThisOneIsAclient, NoIdeaWhatThisOneIs'
-- ===============================================================================================
DECLARE @CreateFunction varchar(MAX)
DECLARE @TargetComputer varchar(256)
DECLARE @TargetComputerID INT
DECLARE @DuplicateTargets varchar(MAX)
DECLARE @DuplicateToValidate varchar(MAX)
DECLARE @StepName varchar(256)
DECLARE @LogMessage varchar(2000)
DECLARE @StepAction varchar(25)
DECLARE @StepMessage varchar(2000)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
--
SET @StepName = 'Add new target computer'
-- ----------------------------------------------------
-- Validate @TargetComputerName
-- ----------------------------------------------------
	IF @TargetComputerName IS NULL
		BEGIN
			SET @StepMessage = 'Please specify at least one target computer and rerun the procedure.  Exiting.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			SET NOEXEC ON
		END
		
-- ----------------------------------------------------
-- Create SplitString function
-- ----------------------------------------------------
IF OBJECT_ID('dbo.SplitString') IS NULL
	BEGIN
		SET @CreateFunction = '
					CREATE FUNCTION SplitString
				(     
					  @Input NVARCHAR(MAX),
					  @Character CHAR(1)
				)
				RETURNS @Output TABLE (
					  SplitOutput NVARCHAR(1000)
				)
				AS
				BEGIN
					  DECLARE @StartIndex INT, @EndIndex INT
 
					  SET @StartIndex = 1
					  IF SUBSTRING(@Input, LEN(@Input) - 1, LEN(@Input)) <> @Character
					  BEGIN
							SET @Input = @Input + @Character
					  END
 
					  WHILE CHARINDEX(@Character, @Input) > 0
					  BEGIN
							SET @EndIndex = CHARINDEX(@Character, @Input)
            
							INSERT INTO @Output(SplitOutput)
							SELECT SUBSTRING(@Input, @StartIndex, @EndIndex - 1)
            
							SET @Input = SUBSTRING(@Input, @EndIndex + 1, LEN(@Input))
					  END
 
					  RETURN
				END'
		--PRINT @CreateFunction
		EXEC (@CreateFunction)
	END
-- ----------------------------------------------------
-- Parse @TargetComputerName
-- ----------------------------------------------------

	IF OBJECT_ID('tempdb.dbo.#TargetComputers') IS NOT NULL
		DROP TABLE #TargetComputers
		--
		CREATE TABLE #TargetComputers (TargetComputer varchar(256) NULL, isProcessed BIT,AlreadyExists BIT)
		--
			INSERT INTO #TargetComputers
				(TargetComputer,isProcessed,AlreadyExists)
			SELECT
				LTRIM(RTRIM(SplitOutput)) AS TargetComputer,
				0 AS isProcessed,
				0 AS AlreadyExists
			FROM
				SplitString(@TargetComputerName,',')

-- ----------------------------------------------------
-- Validate non-duplicate 
-- ----------------------------------------------------
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0)
		BEGIN
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0)
			--
				IF (SELECT 1 FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer) = 1
					BEGIN
						UPDATE #TargetComputers SET AlreadyExists = 1 WHERE TargetComputer = @TargetComputer
					END
				--
				UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		END
	--
	-- Reset isProcessed flag
	--
		UPDATE #TargetComputers SET isProcessed = 0
-- ----------------------------------------------------
-- If not exists, add TargetComputerName to PowerSTIG.ComplianceTargets
-- ----------------------------------------------------
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
		BEGIN
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
			--
				INSERT INTO	PowerSTIG.ComplianceTargets (TargetComputer,isActive,LastComplianceCheck,OSid)
				VALUES
				(@TargetComputer,1,'1900-01-01 00:00:00.000',0)
			--
			UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		END
		--
		-- Reset isProcessed flag
		-- 
			UPDATE #TargetComputers SET isProcessed = 0
-- ----------------------------------------------------
-- Set TargetTypeMap for each target computer
-- ----------------------------------------------------
--WHILE EXISTS
--	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
--		BEGIN TRY
--			SET @StepAction = 'INSERT'
--			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
--			SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
--			SET @StepMessage = 'Target ['+@TargetComputer+'] added.'
--			--

--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@DotNetFramework FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'DotNetFramework'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@FireFox FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'FireFox'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@IISServer FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'IISServer'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@IISSite FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'IISSite'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@InternetExplorer BIT FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'InternetExplorer'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@Excel2013 FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Excel2013'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@Outlook2013 FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Outlook2013'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@PowerPoint2013 FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'PowerPoint2013'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@Word2013 FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Word2013'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@OracleJRE FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'OracleJRE'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@SqlServer2012Database FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'SqlServer2012Database'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@SqlServer2012Instance FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'SqlServer2012Instance'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@SqlServer2016Instance FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'SqlServer2016Instance'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@WindowsClient FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'WindowsClient'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@WindowsDefender FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'WindowsDefender'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@WindowsDNSServer FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'WindowsDNSServer'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@WindowsFirewall FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'WindowsFirewall'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@WindowsServerDC FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'WindowsServerDC'
--				--
--				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
--				SELECT @TargetComputerID,Y.ComplianceTypeID,@WindowsServerMS FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'WindowsServerMS'

		--
		--	UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		--	-- Log the action
		--			EXEC PowerSTIG.sproc_InsertScanLog
		--		   @LogEntryTitle = @StepName
		--		   ,@LogMessage = @StepMessage
		--		   ,@ActionTaken = @StepAction
				   
		--END TRY
		--BEGIN CATCH
		--	SET @ErrorMessage  = ERROR_MESSAGE()
		--	SET @ErrorSeverity = ERROR_SEVERITY()
		--	SET @ErrorState    = ERROR_STATE()
		--	RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--END CATCH
		----
		---- Reset isProcessed flag
		----
		--	UPDATE #TargetComputers SET isProcessed = 0
-- ----------------------------------------------------
-- Notify if TargetComputers already existed.  At present, no action is taken on these target computers
-- so as to remove the potential for orphaning finding data.  This may need to be revisted in the future.
-- ----------------------------------------------------
SET @DuplicateToValidate = ''
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed = 0 AND AlreadyExists = 1)
		
		BEGIN
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 1)
			SET @DuplicateToValidate = @DuplicateToValidate +'||'+ @TargetComputer
			--
			UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		END

	IF LEN(@DuplicateToValidate) > 0
		BEGIN
			SET @StepAction = 'ERROR'
			SET @StepMessage = 'The following supplied target computer(s) appears to exist and therefore no action was taken at this time: ['+ @DuplicateToValidate+']'
			PRINT @StepMessage
					-- Log the action
					EXEC PowerSTIG.sproc_InsertScanLog
				   @LogEntryTitle = @StepName
				   ,@LogMessage = @StepMessage
				   ,@ActionTaken = @StepAction
		END
-- ----------------------------------------------------
-- Cleanup
-- ----------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#TargetComputers') IS NOT NULL
	DROP TABLE #TargetComputers

GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_GetLastComplianceCheckByTarget
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLastComplianceCheckByTarget"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTarget
							@TargetComputer varchar(255)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @TargetComputerID INT
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
--
			SELECT
				T.TargetComputer,
				Y.ComplianceType,
				MAX(L.LastComplianceCheck) AS LastComplianceCheck
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN
						PowerSTIG.ComplianceCheckLog L
							ON T.TargetComputerID = L.TargetComputerID
					JOIN
						PowerSTIG.ComplianceTypes Y
							ON Y.ComplianceTypeID = L.ComplianceTypeID
			WHERE
				T.TargetComputerID = @TargetComputerID
				AND
				Y.ComplianceType != 'UNKNOWN'
			GROUP BY
				T.TargetComputer,Y.ComplianceType
				
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_GetLastComplianceCheckByTargetAndRole
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLastComplianceCheckByTargetAndRole"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole
							@TargetComputer varchar(255),
							@Role varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	--
	DECLARE @TargetComputerID INT
	DECLARE @ComplianceTypeID INT
	SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
	SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = LTRIM(RTRIM(@Role)))
	--
			SELECT
				T.TargetComputer,
				Y.ComplianceType,
				MAX(L.LastComplianceCheck) AS LastComplianceCheck
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN
						PowerSTIG.ComplianceCheckLog L
							ON T.TargetComputerID = L.TargetComputerID
					JOIN
						PowerSTIG.ComplianceTypes Y
							ON Y.ComplianceTypeID = L.ComplianceTypeID
			WHERE
				T.TargetComputerID = @TargetComputerID
				AND
				Y.ComplianceTypeID = @ComplianceTypeID
			GROUP BY
				T.TargetComputer,Y.ComplianceType, L.LastComplianceCheck
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_UpdateConfig
-- ==================================================================
:setvar CREATE_PROC "sproc_UpdateConfig"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_UpdateConfig
			@ConfigProperty varchar(256) = NULL,
			@NewConfigSetting varchar(256) = NULL,
			@NewConfigNote varchar(1000) = NULL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @ConfigID INT
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(2000)
DECLARE @StepAction varchar(25)
SET @ConfigProperty = LTRIM(RTRIM(@ConfigProperty))
SET @NewConfigSetting = LTRIM(RTRIM(@NewConfigSetting))
-- ----------------------------------------------------
-- Validate ConfigProperty input
-- ----------------------------------------------------
	IF @ConfigProperty IS NULL
		BEGIN
			PRINT 'Please specify a ConfigProperty.  Example: EXEC PowerSTIG.sproc_UpdateConfig ''ThisIsAconfigurationProperty'''
			RETURN
		END
		--
		--

	IF NOT EXISTS
		(SELECT TOP 1 ConfigID FROM PowerSTIG.ComplianceConfig WHERE ConfigProperty = @ConfigProperty)
			BEGIN
				PRINT 'The specified configuration property '+@ConfigProperty+' does not appear to be valid. Please specify a valid configuration property'
				RETURN
			END
-- ----------------------------------------------------
-- ConfigProperty validated, get ConfigID
-- ----------------------------------------------------
	SET @ConfigID = (SELECT ConfigID FROM PowerSTIG.ComplianceConfig WHERE ConfigProperty = @ConfigProperty)
-- ----------------------------------------------------
-- Update ConfigSetting
-- ----------------------------------------------------
IF @NewConfigSetting IS NOT NULL
	SET @StepName = 'Update configuration setting'
	SET @StepMessage = 'Update to ConfigID: ['+CAST(@ConfigID AS varchar(25))+'].  The new value is ConfigSetting: ['+@NewConfigSetting+'].'
	SET @StepAction = 'UPDATE'
	--
	BEGIN TRY
				UPDATE
					PowerSTIG.ComplianceConfig
				SET
					ConfigSetting = @NewConfigSetting
				WHERE
					ConfigID = @ConfigID
				--
				-- Log the action
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
-- ----------------------------------------------------
-- Update ConfigNote
-- ----------------------------------------------------
IF @NewConfigNote IS NOT NULL
	BEGIN TRY
		SET @StepName = 'Update configuration note'
		SET @StepMessage = 'Update to ConfigID: ['+CAST(@ConfigID AS varchar(25))+'].  The new value for ConfigNote: ['+@NewConfigSetting+'].'
		SET @StepAction = 'UPDATE'
		
			UPDATE
				PowerSTIG.ComplianceConfig
			SET
				ConfigNote = @NewConfigNote
			WHERE
				ConfigID = @ConfigID
				--
				-- Log the action
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
		
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
-- ----------------------------------------------------
-- ConfigSetting and ConfigNote both NULL, return current setting
-- ----------------------------------------------------
	IF @NewConfigSetting IS NULL AND @NewConfigNote IS NULL
		BEGIN
			SELECT
				ConfigProperty,
				ConfigSetting,
				ConfigNote
			FROM
				PowerSTIG.ComplianceConfig
			WHERE
				ConfigID = @ConfigID
		END
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_InsertConfig
-- ==================================================================
:setvar CREATE_PROC "sproc_InsertConfig"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_InsertConfig
		@NewConfigProperty varchar(256) = NULL,
		@NewConfigSetting varchar(256) = NULL,
		@NewConfigNote varchar(1000) = NULL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(2000)
--
SET @NewConfigProperty = LTRIM(RTRIM(@NewConfigProperty))
SET @NewConfigSetting = LTRIM(RTRIM(@NewConfigSetting))
-- ----------------------------------------------------
-- Validate ConfigProperty and ConfigSetting inputs
-- ----------------------------------------------------
	IF @NewConfigProperty IS NULL OR @NewConfigSetting IS NULL
		BEGIN
			PRINT 'Please specify a ConfigProperty and ConfigSetting.  Example: EXEC PowerSTIG.sproc_UpdateConfig ''ThisIsAconfigurationProperty'', ''ThisIsAconfigurationSetting'''
			RETURN
		END

-- ----------------------------------------------------
-- Insert
-- ----------------------------------------------------
	BEGIN TRY
		SET @StepName = 'Update configuration note'
		SET @StepMessage = 'Update to ConfigID: ['+@NewConfigProperty+'].  The new value for ConfigNote: ['+@NewConfigSetting+'].'
		SET @StepAction = 'UPDATE'

		--
		INSERT INTO
			PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote)
		VALUES
			(
			@NewConfigProperty,
			@NewConfigSetting,
			@NewConfigNote
			)
				--
				-- Log the action
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
		
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_GetScanQueue
-- ==================================================================
:setvar CREATE_PROC "sproc_GetScanQueue"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerStig.sproc_GetScanQueue 
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
			SELECT
				TargetComputer,
				ComplianceType,
				QueueStart,
				QueueEnd
			FROM
				PowerSTIG.ScanQueue
			WHERE
				QueueEnd = '1900-01-01 00:00:00.000'
				OR
				QueueEnd IS NULL
			ORDER BY
				QueueStart DESC
	
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_DeleteTargetComputerAndData
-- ==================================================================
:setvar CREATE_PROC "sproc_DeleteTargetComputerAndData"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerStig.sproc_DeleteTargetComputerAndData
					@TargetComputer varchar(255)
AS
SET NOCOUNT ON
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
-- Purpose: Removes all data and references to the specified TargetComputer.  The only remaining references to
-- the specified TargetComputer will be contained in the ScanLog table.
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @TargetComputerID INT
DECLARE @StepName varchar(256)
DECLARE @StepAction varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @LogTheUser varchar(256)
--
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
SET @LogTheUser = (SELECT SUSER_NAME() AS LogTheUser)
SET @StepMessage = ('Delete requested by ['+@LogTheUser+'] for target computer ['+ LTRIM(RTRIM(@TargetComputer))+'].')
--
-- Invalid TargetComputer specified
-- 
	IF @TargetComputerID IS NULL
		BEGIN
			SET @StepMessage = 'The specified target computer ['+LTRIM(RTRIM(@TargetComputer))+'] was not found.  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			SET NOEXEC ON
		END

--
--
SET @StepName = 'Delete from table FindingRepo.'
SET @StepAction = 'DELETE'
--
	BEGIN TRY
	SET @StepMessage = 'Delete target computer ['+@TargetComputer+'] from table FindingRepo.'
		DELETE FROM 
			PowerSTIG.FindingRepo
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH

----
--SET @StepName = 'Delete from table TargetTypeMap'
----
--	BEGIN TRY
--		SET @StepMessage = 'Delete target computer ['+@TargetComputer+'] from table TargetTypeMap.'
--		DELETE FROM 
--			PowerSTIG.TargetTypeMap
--		WHERE
--			TargetComputerID = @TargetComputerID
--		--
--		-- Log the delete
--		--
--		EXEC PowerSTIG.sproc_InsertScanLog
--				@LogEntryTitle = @StepName
--				,@LogMessage = @StepMessage
--				,@ActionTaken = @StepAction
--		--
--	END TRY
--	BEGIN CATCH
--			SET @StepAction = 'ERROR'
--		    SET @ErrorMessage  = ERROR_MESSAGE()
--			SET @ErrorSeverity = ERROR_SEVERITY()
--			SET @ErrorState    = ERROR_STATE()
--			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
--			--
--			EXEC PowerSTIG.sproc_InsertScanLog
--				@LogEntryTitle = @StepName
--				,@LogMessage = @ErrorMessage
--				,@ActionTaken = @StepAction
--	END CATCH
	


--
SET @StepName = 'Delete from ComplianceCheckLog'
--
	BEGIN TRY
		SET @StepMessage = 'Delete target computer ['+@TargetComputer+'] from table ComplianceCheckLog.'
		DELETE FROM 
			PowerSTIG.ComplianceCheckLog
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH

--
SET @StepName = 'Delete from ComplianceTargets'
--
	BEGIN TRY
		SET @StepMessage = 'Delete target computer ['+@TargetComputer+'] from table ComplianceTargets.'
		DELETE FROM 
			PowerSTIG.ComplianceTargets
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH

GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_InsertFindingImport
-- ==================================================================
:setvar CREATE_PROC "sproc_InsertFindingImport"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO


CREATE OR ALTER PROCEDURE PowerSTIG.sproc_InsertFindingImport
				@PScomputerName varchar(255)
				,@VulnID varchar(25) 
				,@StigType varchar(256) 
				,@DesiredState varchar(25)
				,@ScanDate datetime
				,@GUID UNIQUEIDENTIFIER
				,@ScanSource varchar(25)
				,@ScanVersion varchar(8)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- 04082019 - Kevin Barlett, Microsoft - Modifications for SCAP + PowerSTIG integration.
--Use example:
--EXEC PowerSTIG.sproc_InsertFindingImport 'SERVER2012','V-26529','OracleJRE','True','09/17/2018 14:32:42','5B1DD2AD-025A-4264-AD0C-E11107F88004','SCAP','1.03'
--EXEC PowerSTIG.sproc_InsertFindingImport 'SERVER2012','V-26529','DotNetFramework','True','09/17/2018 14:32:42','5B1DD2AD-025A-4264-AD0C-E11107F88004','POWERSTIG','4.31'
-- ===============================================================================================
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
--
BEGIN TRY
	INSERT INTO PowerSTIG.FindingImport
		(
		TargetComputer,
		VulnID,
		StigType,
		DesiredState,
		ScanDate,
		[GUID],
		ScanSource,
		ImportDate,
		ScanVersion
		)
	VALUES
		(
		@PScomputerName,
		@VulnID,
		@StigType,
		@DesiredState,
		@ScanDate,
		@GUID,
		@ScanSource,
		GETDATE(),
		@ScanVersion
		)
END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_ProcessFindings
-- ==================================================================
:setvar CREATE_PROC "sproc_ProcessFindings"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_ProcessFindings] 
							@GUID varchar(128)
							
AS
SET NOCOUNT ON
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
-- ===============================================================================================
-- Purpose: Processes (normalizes, mostly) data from the FindingImport table to the FindingRepo table.
-- Revisions:
-- 11012018 - Kevin Barlett, Microsoft - Initial creation.
-- 04082019 - Kevin Barlett, Microsoft - Modifications for SCAP + PowerSTIG integration.
-- Use example:
-- EXEC PowerSTIG.sproc_ProcessFindings @GUID='242336A7-FA89-4F25-8D9C-97B566AEE3F7'
-- EXEC PowerSTIG.sproc_ProcessFindings @GUID='242336A7-FA89-4F25-8D9C-97B566AEE3F7'
-- ===============================================================================================
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(2000)
DECLARE @StepAction varchar(25)
DECLARE @LastComplianceCheck datetime
DECLARE @ScanID INT
DECLARE @NewStigType varchar(128)
DECLARE @ScanSourceID smallint
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint

-- =======================================================
-- Retrieve new GUIDs
-- =======================================================
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.Scans (ScanGUID,ScanSourceID,ScanDate,ScanVersion)
		SELECT DISTINCT
			I.[GUID]
			,S.ScanSourceID
			,I.ScanDate
			,I.ScanVersion
		FROM
			PowerSTIG.FindingImport I
				JOIN PowerSTIG.ScanSource S
					ON I.ScanSource = S.ScanSource
		WHERE I.[GUID] NOT IN
			(SELECT ScanGUID FROM PowerSTIG.Scans)

	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

-- =======================================================
-- Hydrate Finding
-- =======================================================
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.Finding(Finding)
		SELECT DISTINCT
			LTRIM(RTRIM(VulnID)) AS Finding
		FROM 
			PowerSTIG.FindingImport
		WHERE
			LTRIM(RTRIM(VulnID)) NOT IN (SELECT Finding FROM PowerSTIG.Finding)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

-- =======================================================
-- Hydrate ComplianceType
-- =======================================================
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.ComplianceTypes(ComplianceType,isActive)
		SELECT DISTINCT
			StigType,
			1 AS isActive
		FROM 
			PowerSTIG.FindingImport
		WHERE
			StigType NOT IN (SELECT ComplianceType FROM PowerSTIG.ComplianceTypes)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Hydrate FindingRepo
-- =======================================================
	BEGIN TRY

			WHILE EXISTS
				(SELECT TOP 1 ScanID FROM PowerSTIG.Scans WHERE [ScanGUID] = @GUID AND isProcessed = 0)
					BEGIN
						SET @ScanID = (SELECT TOP 1 ScanID FROM PowerSTIG.Scans WHERE [ScanGUID] = @GUID AND isProcessed = 0)

				INSERT INTO
					PowerSTIG.FindingRepo (TargetComputerID,FindingID,InDesiredState,ComplianceTypeID,ScanID)
				SELECT
					T.TargetComputerID,
					F.FindingID,
					CASE
						WHEN I.DesiredState = 'True' THEN 1
						WHEN I.DesiredState = 'False' THEN 0
						END AS InDesiredState,
					C.ComplianceTypeID,
					@ScanID AS ScanID
				FROM
					PowerSTIG.FindingImport I
						JOIN 
							PowerSTIG.ComplianceTargets T
								ON I.TargetComputer = T.TargetComputer
						JOIN 
							PowerSTIG.Finding F
								ON I.VulnID = F.Finding
						JOIN
							PowerSTIG.ComplianceTypes C
								ON C.ComplianceType = I.StigType
						JOIN 
							PowerSTIG.Scans S
								ON I.[GUID] = S.ScanGUID
				WHERE
					S.ScanID = @ScanID

				--
				-- Set the ScanID as Processed
				--
					UPDATE
						PowerSTIG.Scans
					SET
						isProcessed = 1
					WHERE
						ScanID = @ScanID
		END

	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

-- =======================================================
-- Update ComplianceCheckLog
-- =======================================================
	BEGIN TRY
			SET @ScanID = (SELECT ScanID FROM PowerSTIG.Scans WHERE ScanGUID = @GUID)
			SET @LastComplianceCheck = (SELECT GETDATE())
	--
	INSERT INTO
			PowerSTIG.ComplianceCheckLog (ScanID,TargetComputerID,ComplianceTypeID,LastComplianceCheck)
		SELECT DISTINCT
			ScanID,
			TargetComputerID,
			ComplianceTypeID,
			@LastComplianceCheck AS LastComplianceCheck
		FROM
			PowerSTIG.FindingRepo
		WHERE
			ScanID = @ScanID
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Update ComplianceTargets
-- =======================================================
	BEGIN TRY
			UPDATE
				PowerSTIG.ComplianceTargets
			SET
				LastComplianceCheck = @LastComplianceCheck
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN PowerSTIG.ComplianceCheckLog L
						ON T.TargetComputerID = L.TargetComputerID
			WHERE
				L.ScanID = @ScanID
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Cleanup
-- =======================================================
DROP TABLE IF EXISTS #NewComplianceTarget
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
/*
-- ==================================================================
-- sproc_GetLastDataForCKL
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLastDataForCKL"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetLastDataForCKL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 01072019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLE: EXEC PowerSTIG.sproc_GetLastDataForCKL
-- ===============================================================================================
--
DROP TABLE IF EXISTS #RecentScan

-- =======================================================
-- Find the most recent scan for each target + compliance type combination
-- =======================================================
			SELECT * INTO #RecentScan FROM (
		SELECT
				T.TargetComputer,
			Y.ComplianceType,
			--TargetComputerID,
			--ComplianceTypeID,
			S.ScanID,
			S.ScanGUID,

			ROW_NUMBER() OVER(PARTITION BY L.ComplianceTypeID,L.TargetComputerID ORDER BY L.LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog L
				JOIN PowerSTIG.ComplianceTargets T
					ON L.TargetComputerID = T.TargetComputerID
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON L.ComplianceTypeID = Y.ComplianceTypeID
			JOIN PowerSTIG.Scans S
				ON S.ScanID = L.ScanID

		--WHERE
		--	TargetComputerID = 46--@TargetComputerID
			) T
		WHERE
			T.RowNum = 1
-- =======================================================
-- Return results
-- =======================================================
	SELECT 
		TargetComputer,
		ComplianceType,
		ScanGUID
	FROM
		#RecentScan
	ORDER BY
		TargetComputer,ComplianceType ASC

-- =======================================================
-- Cleanup
-- =======================================================
DROP TABLE IF EXISTS #RecentScan
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
*/
-- ==================================================================
-- sproc_GetScanLog
-- ==================================================================
:setvar CREATE_PROC "sproc_GetScanLog"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetScanLog
					@LogDate datetime =  NULL			
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 02122019 - Kevin Barlett, Microsoft - Initial creation.
-- Use example:
-- EXEC PowerSTIG.sproc_GetScanLog
-- EXEC PowerSTIG.sproc_GetScanLog @LogDate='2019-04-25 00:00:00.000'
-- ===============================================================================================
--
	IF (@LogDate)IS NULL OR (@LogDate) = ''
		SET @LogDate = (SELECT DATEADD(day, 0, DATEDIFF(day, 0, GETDATE())))
--

	SELECT
		LogTS,
		LogEntryTitle,
		LogMessage,
		ActionTaken,
		LoggedUser
	FROM
		PowerSTIG.ScanLog
	WHERE
		DATEADD(day, 0, DATEDIFF(day, 0, LogTS)) = @LogDate
	ORDER BY
		LogTS DESC
	--OPTION(OPTIMIZE FOR UNKNOWN )
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_ImportSTIGxml
-- ==================================================================
:setvar CREATE_PROC "sproc_ImportSTIGxml"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_ImportSTIGxml
				@STIGfile varchar(384),
				@TargetRole varchar(256)
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
-- ====================================================================================
-- Purpose:
-- Revisions:
-- 03132019 - Kevin Barlett, Microsoft - Initial creation.
-- Use examples:
-- EXEC PowerSTIG.sproc_ImportSTIGxml @STIGfile = 'C:\Program Files\WindowsPowerShell\Modules\PowerSTIG\2.4.0.0\StigData\Processed\Windows-2012R2-MS-2.14.xml',@TargetRole='MemberServer'
-- ====================================================================================
SET NOCOUNT ON
--
DECLARE @XML AS XML
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @SQLcmd varchar(MAX)
--DECLARE @CKL_XML TABLE (ID tinyint IDENTITY(1,1), CheckList VARCHAR(MAX))
-- -------------------------------
-- Validate OrgFile
-- -------------------------------
SET @StepName = 'Validate XML file existance'
--
SET @STIGfile = LTRIM(RTRIM(@STIGfile))
--
	  DECLARE @FileExistsCheck TABLE (FileExists bit,
                                FileIsADirectory bit,
                                ParentDirectoryExists bit)
	  INSERT INTO @FileExistsCheck (FileExists, FileIsADirectory, ParentDirectoryExists)
	  EXECUTE [master].dbo.xp_fileexist @STIGfile

	  -- Bail if Org file fails existance check
	  IF EXISTS (SELECT * FROM @FileExistsCheck WHERE FileExists = 0)
			BEGIN
				SET @StepMessage = 'The specified STIG XML file: ['+@STIGfile+'] was not found or could not be read.  Please validate.'
				SET @StepAction = 'ERROR'
				PRINT @StepMessage
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
				   ,@LogMessage = @StepMessage
				   ,@ActionTaken = @StepAction
				RETURN
			END
	  ELSE
			BEGIN
				SET @StepMessage = ('The specified STIG XML file ['+@STIGfile+'] was found and appears to be valid.')
				SET @StepAction = 'UPDATE'
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
				   ,@LogMessage = @StepMessage
				   ,@ActionTaken = @StepAction
			END

-- -------------------------------
-- Validate TargetRole
-- -------------------------------
--SET @StepName = 'Validate supplied target role'
----
--SET @TargetRole = LTRIM(RTRIM(@TargetRole))
----
--		IF NOT EXISTS (SELECT TOP 1 ComplianceType FROM PowerSTIG.ComplianceTypes WHERE ComplianceType LIKE @TargetRole)
--			BEGIN
--				SET @ValidComplianceTypes = (SELECT ComplianceType FROM PowerSTIG.ComplianceTypes WHERE isActive = 1)
--				SET @StepMessage = 'The specified target role: ['+@TargetRole+'] does not appear to be valid  Valid target roles are:'+char(13)+
--				@ValidComplianceTypes+
--				'.  Please validate.'
--				SET @StepAction = 'ERROR'
--				PRINT @StepMessage
--				--
--				EXEC PowerSTIG.sproc_InsertScanLog
--					@LogEntryTitle = @StepName
--				  ,@LogMessage = @StepMessage
--				  ,@ActionTaken = @StepAction
--				RETURN
--			END
--		ELSE
--			BEGIN
--				SET @TargetRoleID = (SELECT TOP 1 ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType LIKE @TargetRole)
--				SET @StepMessage = ('The specified target role ['+@TargetRole+'] was found and is active.')
--				SET @StepAction = 'UPDATE'
--				--
--				EXEC PowerSTIG.sproc_InsertScanLog
--					@LogEntryTitle = @StepName
--				   ,@LogMessage = @StepMessage
--				   ,@ActionTaken = @StepAction
--			END

-- -------------------------------
-- Import STIG file
-- -------------------------------
SET @StepName = 'Import STIG XML file'
--
	BEGIN TRY
		IF OBJECT_ID('#ImportSTIGSettings') IS NOT NULL
		DROP TABLE #ImportSTIGSettings
	--
		CREATE TABLE #ImportSTIGSettings
			(
				ImportID INT IDENTITY(1,1) PRIMARY KEY,
				XMLData XML,
				LoadedDateTime DATETIME
			)


		SET @SQLcmd = 'INSERT INTO #ImportSTIGSettings (XMLData,LoadedDateTime)
							SELECT CONVERT(XML, BulkColumn) AS BulkColumn, GETDATE() 
							FROM OPENROWSET(BULK '''+@STIGfile+''', SINGLE_BLOB) AS x;'
		--PRINT @SQLcmd
		EXEC (@SQLcmd)
		--
		SET @StepMessage = ('XML file ['+@STIGfile+'] contents loaded.  Now processing.')
		SET @StepAction = 'UPDATE'
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
		SET @ErrorMessage  = ERROR_MESSAGE()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState    = ERROR_STATE()
		--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--
		SET @StepMessage = 'Error encountered loading the contents of: ['+@STIGfile+'] to the database.  Captured error info: '+@ErrorMessage+'  Please validate.'
		SET @StepAction = 'ERROR'
		PRINT @StepMessage
				--
		EXEC PowerSTIG.sproc_InsertScanLog
			@LogEntryTitle = @StepName
		   ,@LogMessage = @StepMessage
		   ,@ActionTaken = @StepAction
		RETURN
	END CATCH

-- -------------------------------
-- Parse XML
-- -------------------------------
SET @StepName = 'Parse STIG XML file'
--
	BEGIN TRY
		IF OBJECT_ID('tempdb.dbo.#XMLimport') IS NOT NULL
			DROP TABLE [#XMLimport]
		--
		CREATE TABLE [dbo].[#XMLimport](
				[RuleID] [nvarchar](10) NULL,
				[Severity] [nvarchar](25) NULL,
				[Title] [nvarchar](128) NULL,
				[DSCresource] [nvarchar](128) NULL,
				[RawString] [nvarchar](max) NULL,
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
			--
			--

			--insert the XML template into @Table
			DECLARE @CKL_XML TABLE (ID tinyint IDENTITY(1,1), CheckList XML)
							INSERT INTO @CKL_XML
							SELECT TOP 1 CONVERT(XML,XMLData)FROM [dbo].[#ImportSTIGSettings]
			--
			INSERT INTO [#XMLimport]
	  SELECT
				tbl.col.value('(.//@id)[1]', 'nvarchar(10)')						 			    AS RuleID
				,tbl.col.value('(.//@severity)[1]', 'nvarchar(25)')								    AS Severity
				,tbl.col.value('(.//@title)[1]', 'nvarchar(128)')									AS Title
				,tbl.col.value('(.//@dscresource)[1]', 'nvarchar(128)')								AS DSCresource	
				,tbl.col.value('(.//RawString)[1]', 'nvarchar(max)')								AS RawString

		FROM 
			@CKL_XML xt
		CROSS APPLY 
			CheckList.nodes('/DISASTIG/*/Rule, ./*/*') tbl(col)
		--
		SET @StepMessage = ('STIG XML file ['+@STIGfile+'] parsed successfully.')
		SET @StepAction = 'INSERT'
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
		SET @ErrorMessage  = ERROR_MESSAGE()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState    = ERROR_STATE()
		--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--
		SET @StepMessage = 'Error encountered parsing the contents of: ['+@STIGfile+'].  Captured error info: '+@ErrorMessage+'  Please validate.'
		SET @StepAction = 'ERROR'
		PRINT @StepMessage
				--
		EXEC PowerSTIG.sproc_InsertScanLog
			@LogEntryTitle = @StepName
		   ,@LogMessage = @StepMessage
		   ,@ActionTaken = @StepAction
			RETURN
		END CATCH
-- -------------------------------
-- Import to StigTextRepo
-- -------------------------------
	-- First delete if the RuleID already exists
	BEGIN TRY
		DELETE FROM 
			PowerSTIG.StigTextRepo
		WHERE
			RuleID IN (SELECT RuleID FROM [#XMLimport])
		--
		INSERT INTO
			PowerSTIG.StigTextRepo (RuleID,Severity,Title,DSCresource,RawString)
		SELECT
			RuleID
			,Severity
			,Title
			,DSCresource
			,RawString
		FROM
			#XMLimport

	END TRY
	BEGIN CATCH
		SET @ErrorMessage  = ERROR_MESSAGE()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState    = ERROR_STATE()
		--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--
		SET @StepMessage = 'Error loading the contents of: ['+@STIGfile+'] to the StigTextRepo.  Captured error info: '+@ErrorMessage+'  Please validate.'
		SET @StepAction = 'ERROR'
		PRINT @StepMessage
				--
		EXEC PowerSTIG.sproc_InsertScanLog
			@LogEntryTitle = @StepName
		   ,@LogMessage = @StepMessage
		   ,@ActionTaken = @StepAction
			RETURN
	END CATCH

-- -------------------------------
-- Cleanup
-- -------------------------------
	IF OBJECT_ID('tempdb.dbo.#ImportSTIGSettings') IS NOT NULL
		DROP TABLE #ImportSTIGSettings
--
	IF OBJECT_ID('tempdb.dbo.#XMLimport') IS NOT NULL
		DROP TABLE #XMLimport
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GetCountServers
-- ==================================================================
:setvar CREATE_PROC "sproc_GetCountServers"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetCountServers]
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 01242019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
-- 
-- Retrieve count of active/inactive targets
SELECT 
	COUNT(TargetComputerID) AS ActiveTargets,
	InActiveTargets = (SELECT COUNT(TargetComputerID) FROM [PowerSTIG].[ComplianceTargets] WHERE isActive = 0)
FROM
	[PowerSTIG].[ComplianceTargets]
WHERE
	isActive = 1
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GetComplianceStateByRole
-- ==================================================================
:setvar CREATE_PROC "sproc_GetComplianceStateByRole"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetComplianceStateByRole
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 03252019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DROP TABLE IF EXISTS #ComplianceStateByRole
--

SELECT * INTO #ComplianceStateByRole FROM (
		SELECT
			--IterationID,
			--TargetComputerID,
			ComplianceTypeID,
			ScanID,
			ROW_NUMBER() OVER(PARTITION BY ComplianceTypeID ORDER BY LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog

			) T
		WHERE
			T.RowNum = 1

--
-- Display data
--
	SELECT 
		T.ComplianceType
		,COUNT(CASE WHEN InDesiredState = 1 THEN 1 ELSE NULL END) AS Compliant
		,COUNT(CASE WHEN InDesiredState = 0 THEN 0 ELSE NULL END) AS NonCompliant
		,COUNT(*) AS FindingComplianceCount
	FROM 
		PowerSTIG.FindingRepo R
			JOIN PowerSTIG.ComplianceTypes T
				ON R.ComplianceTypeID = T.ComplianceTypeID
	WHERE
		R.ScanID IN (SELECT ScanID FROM #ComplianceStateByRole)
	GROUP BY
		T.ComplianceType
--
-- Cleanup
--
	DROP TABLE IF EXISTS #ComplianceStateByRole
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
/*
-- ==================================================================
-- PowerStig.sproc_InitiateManualScan
-- ==================================================================
:setvar CREATE_PROC "sproc_InitiateManualScan"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerStig.sproc_InitiateManualScan
								@TargetComputerID INT
								,@ComplianceTypeID INT
AS
SET NOCOUNT ON
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
-- loss of buasiness information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 03252019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--DECLARE @TargetComputerID INT
--DECLARE @ComplianceTypeID INT
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @TargetComputer varchar(256)
DECLARE @ComplianceType varchar(256)
SET @TargetComputer = (SELECT TargetComputer FROM PowerSTIG.ComplianceTargets WHERE TargetComputerID = @TargetComputerID)
SET @ComplianceType = (SELECT ComplianceType FROM PowerSTIG.ComplianceTypes WHERE ComplianceTypeID = @ComplianceTypeID)
--SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
--SET @ComplianceTypeID = (SELECT @ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = LTRIM(RTRIM(@ComplianceType)))
SET @StepMessage = ('A manual scan was initiated against target: ['+@TargetComputer+'] for compliance type: ['+@ComplianceType+'].  Scan requested by ['+SUSER_NAME()+'].')
--
	BEGIN TRY

		SET @StepName = 'Initiate Manual Scan'
		SET @StepAction = 'UPDATE'
	--
	-- Truncate PowerStig.ScanQueue
	--
		--TRUNCATE TABLE PowerStig.ScanQueue
	--
	-- Hydrate ScanQueue
	--
			INSERT INTO PowerStig.ScanQueue (TargetComputer,ComplianceType,QueueStart,QueueEnd)
			SELECT
				T.TargetComputer,
				Y.ComplianceType,
				GETDATE() AS QueueStart,
				'1900-01-01 00:00:00.000' AS QueueEnd
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN PowerSTIG.TargetTypeMap M
						ON T.TargetComputerID = M.TargetComputerID
					JOIN PowerSTIG.ComplianceTypes Y
						ON M.ComplianceTypeID = Y.ComplianceTypeID
			WHERE
				T.TargetComputerID = @TargetComputerID
				AND
				Y.ComplianceTypeID = @ComplianceTypeID
			--
			-- Perform logging
			--	
				EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
			--
			-- Return queued scans
			--
			SELECT
				TargetComputer,
				ComplianceType,
				QueueStart,
				QueueEnd
			FROM
				PowerSTIG.ScanQueue
			ORDER BY
				QueueStart DESC
			--
		END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
*/
-- ==================================================================
-- PowerStig.sproc_GetTargetComplianceTypeLastCheck
-- ==================================================================
:setvar CREATE_PROC "sproc_GetTargetComplianceTypeLastCheck"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerStig.sproc_GetTargetComplianceTypeLastCheck
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 01242019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
-- 
DROP TABLE IF EXISTS #RecentScan
--
SELECT * INTO #RecentScan FROM (
		SELECT
			--IterationID,
			TargetComputerID,
			ComplianceTypeID,
			ScanID,
			ROW_NUMBER() OVER(PARTITION BY ComplianceTypeID,TargetComputerID ORDER BY LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog
		--WHERE
		--	TargetComputerID = 44--@TargetComputerID
			) T
--
-- Return data
--
	
SELECT
	T.TargetComputerID
	,T.TargetComputer
	,Y.ComplianceTypeID
	,Y.ComplianceType
	,L.LastComplianceCheck
FROM
	[PowerSTIG].[ComplianceTargets] T
		JOIN
			[PowerSTIG].[ComplianceCheckLog] L
				ON T.TargetComputerID = L.TargetComputerID
		JOIN
			[PowerSTIG].[ComplianceTypes] Y
				ON Y.ComplianceTypeID = L.ComplianceTypeID
WHERE
	L.ScanID IN (SELECT ScanID FROM #RecentScan WHERE RowNum = 1)
ORDER BY
	TargetComputer,ComplianceType
--
-- Cleanup
-- 
DROP TABLE IF EXISTS #RecentScan
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
/*
-- ==================================================================
-- PowerStig.sproc_TargetRoleScanDash
-- ==================================================================
:setvar CREATE_PROC "sproc_TargetRoleScanDash"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerStig.sproc_TargetRoleScanDash
					@TargetComputerID INT
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 01252019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
-- 
--DECLARE @TargetComputerID INT
--SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))

	--
	SELECT DISTINCT
		T.TargetComputerID
		,T.TargetComputer
		,Y.ComplianceTypeID
		,Y.ComplianceType
		,'Initiate Scan' as [Action]
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 1
		AND
		T.isActive = 1
		AND
		T.TargetComputerID = @TargetComputerID
UNION
	SELECT
		S.TargetComputerID
		,S.TargetComputer
		--LTRIM(RTRIM(@TargetComputer)) AS TargetComputer,
		,Y.ComplianceTypeID
		,'ALL' AS ComplianceType
		,'Scan ALL Active Roles' AS [Action]
	FROM
		PowerSTIG.ComplianceTargets S
			JOIN PowerSTIG.TargetTypeMap M
				ON S.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 1
		AND
		S.isActive = 1
		AND
		S.TargetComputerID = @TargetComputerID

GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
*/
-- ==================================================================
-- PowerStig.sproc_GenerateDates
-- ==================================================================
:setvar CREATE_PROC "sproc_GenerateDates"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerStig.sproc_GenerateDates
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 03262019 - Kevin Barlett, Microsoft - Initial creation. [NEEDS WORK]
-- ===============================================================================================
--
DECLARE @BeginDate datetime
DECLARE @EndDate datetime
DECLARE @Interval smallint
SET @BeginDate = (GETDATE()-90)
SET @EndDate = (GETDATE())
SET @Interval = 300
--
		IF OBJECT_ID('tempdb.dbo.#ArrayOfDates') IS NOT NULL
		DROP TABLE #ArrayOfDates
		--
		CREATE TABLE #ArrayOfDates 
		(
			DateID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
			BeginDate datetime,
			EndDate datetime
		)
--create table #T (date_begin datetime, date_end datetime)    

--declare @StartTime datetime = '2011-07-20 11:00:33',
--declare @StartTime datetime = getdate()-90,
    --@EndTime datetime = '2011-07-20 15:37:34',
--	  @EndTime datetime = getdate(),
  --  @Interval int = 554 -- this can be changed.

WHILE DATEADD(ss,@Interval,@BeginDate)<=@EndDate
BEGIN
    INSERT INTO #ArrayOfDates (BeginDate,EndDate)
    SELECT @BeginDate, DATEADD(ss,@Interval,@BeginDate)

    SET @BeginDate = DATEADD(ss,@Interval,@BeginDate)
END
--
-- Return dates
--
SELECT 
	BeginDate
	,EndDate
FROM
	#ArrayOfDates
ORDER BY
	DateID DESC
--
-- Cleanup
--
	--IF OBJECT_ID('tempdb.dbo.#ArrayOfDates') IS NOT NULL
	--	DROP TABLE #ArrayOfDates
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GetAdminFunction 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetAdminFunction"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerStig.sproc_GetAdminFunction 
						@AdminName varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 03262019 - Kevin Barlett, Microsoft - Initial creation. [NEEDS WORK]
-- ===============================================================================================
--
	IF @AdminName IN (SELECT FQDNandAdmin FROM PowerSTIG.AdminFunctionUsers)
		BEGIN
			SELECT
				F.FunctionID
				,F.FunctionName
				,F.FunctionDescription
				,F.FunctionPage
			FROM
				PowerSTIG.AdminFunctionsMap M
					JOIN 
						PowerSTIG.AdminFunction F
						ON M.FunctionID = F.FunctionID
					JOIN
						PowerSTIG.AdminFunctionUsers U
						ON U.AdminID = M.AdminID 
			WHERE
				U.FQDNandAdmin = @AdminName
				--U.FQDNandAdmin = SUSER_NAME()
				AND
				M.isActive = 1
			ORDER BY
				FunctionName
		END
	ELSE
		BEGIN
			SELECT
				'No admin functions available' AS FunctionName,
				'No admin function descriptions available' AS FunctionDescription
			FROM
				PowerSTIG.AdminFunction
			WHERE
				FunctionID = 1
			END
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GetComplianceStats 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetComplianceStats"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetComplianceStats]
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 01242019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
--
-- 
	DROP TABLE IF EXISTS #RecentScan
--

SELECT * INTO #RecentScan FROM (
		SELECT
			--IterationID,
			TargetComputerID,
			ComplianceTypeID,
			ScanID,
			ROW_NUMBER() OVER(PARTITION BY ComplianceTypeID ORDER BY LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog
		--WHERE
		--	TargetComputerID = 44--@TargetComputerID
			) T
		WHERE
			T.RowNum = 1

--
-- Display data
--
	SELECT 
		CASE 
			WHEN InDesiredState = 0 THEN 'Non-Compliant Findings'
			WHEN InDesiredState = 1 THEN 'Compliant Findings'
			END AS CurrentState
			,COUNT(*) AS FindingComplianceCount
	FROM 
		PowerSTIG.FindingRepo
	WHERE
		ScanID IN (SELECT ScanID FROM #RecentScan)
	GROUP BY
		InDesiredState
--
-- Cleanup
--
	DROP TABLE IF EXISTS #RecentScan
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GetStigTextByTargetScanCompliance 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetStigTextByTargetScanCompliance"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER   PROCEDURE [PowerSTIG].[sproc_GetStigTextByTargetScanCompliance]
					        @TargetComputerID INT
							,@ComplianceTypeID INT
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 03142019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
-- ----------------------------------------
-- Find most recent scan
-- ----------------------------------------
	DROP TABLE IF EXISTS #RecentScan
		--
		CREATE TABLE #RecentScan (
			TargetComputerID INT NULL,
			ComplianceTypeID INT NULL,
			ScanID INT NULL,
			RowNum INT NULL)
	--
	INSERT INTO #RecentScan (TargetComputerID,ComplianceTypeID,ScanID,RowNum)
	SELECT 
		TargetComputerID,
		ComplianceTypeID,
		ScanID,
		RowNum
	FROM (
		SELECT
			TargetComputerID,
			ComplianceTypeID,
			ScanID,
			ROW_NUMBER() OVER(PARTITION BY ComplianceTypeID ORDER BY LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog
		WHERE
			TargetComputerID = @TargetComputerID
			) T
		WHERE
			T.RowNum = 1
-- ----------------------------------------
--
-- ----------------------------------------
	SELECT
		R.InDesiredState
		,S.RuleID
		,S.Severity
		,S.Title
		,S.RawString AS CheckDescription
		--,S.FixText
		,L.LastComplianceCheck
	FROM
			PowerSTIG.FindingRepo R
				INNER JOIN PowerSTIG.Finding F
					ON R.FindingID = F.FindingID
						INNER JOIN PowerSTIG.StigTextRepo S
							ON F.Finding = S.RuleID
								INNER JOIN PowerSTIG.ComplianceTypes T
									ON T.ComplianceTypeID = R.ComplianceTypeID
										INNER JOIN
											PowerSTIG.ComplianceCheckLog L
												ON L.ScanID = R.ScanID
	WHERE 
			R.ScanID = (SELECT MAX(ScanID) FROM #RecentScan WHERE ComplianceTypeID = @ComplianceTypeID)
			AND
			R.TargetComputerID = @TargetComputerID
			AND
			T.ComplianceTypeID = @ComplianceTypeID
-- ----------------------------------------
-- Cleanup
-- ----------------------------------------
	DROP TABLE IF EXISTS #RecentScan
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GetQueuedScans 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetQueuedScans"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER   PROCEDURE [PowerSTIG].[sproc_GetQueuedScans]
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 03142019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
			SELECT
				TargetComputer,
				ComplianceType,
				QueueStart,
				QueueEnd
			FROM
				PowerSTIG.ScanQueue
			ORDER BY
				QueueStart DESC
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_InsertNewScan 
-- ==================================================================
:setvar CREATE_PROC "sproc_InsertNewScan"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_InsertNewScan]
						@GUID uniqueidentifier
						,@ScanSource varchar(25)
						--,@ComplianceType varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04092019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ScanSourceID smallint
--DECLARE @ComplianceTypeID INT
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
SET @ScanSourceID = (SELECT ScanSourceID FROM PowerSTIG.ScanSource WHERE ScanSource = @ScanSource)
--SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
--
	BEGIN TRY
		INSERT INTO PowerSTIG.Scans
			(ScanGUID,
			ScanSourceID,
			ScanDate,
			isProcessed
			)
		VALUES
			(@GUID,
			@ScanSourceID,
			GETDATE(),
			0)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_UpdateTargetOS 
-- ==================================================================
:setvar CREATE_PROC "sproc_UpdateTargetOS"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_UpdateTargetOS]
				@TargetComputer varchar(256),
				@OSname varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04102019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @OSid smallint
DECLARE @TargetComputerID INT
SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = @OSname)
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
--
SET @StepName = 'Set OS version for compliance target'
	BEGIN TRY
		UPDATE 
			PowerSTIG.ComplianceTargets
		SET
			OSid = @OSid
		WHERE
			TargetComputerID = @TargetComputerID
		--
		SET @StepMessage = 'OS version ['+@OSname+'] successfully set for target computer ['+@TargetComputer+'].'
		SET @StepAction = 'UPDATE'
			--
		EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
			
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error setting OS version: ['+@OSname+'] to target computer ['+@TargetComputer+'].  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- PowerStig.sproc_GenerateORGxml 
-- ==================================================================
:setvar CREATE_PROC "sproc_GenerateORGxml"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GenerateORGxml
			@OSname varchar(128)
			,@ComplianceType varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04112019 - Kevin Barlett, Microsoft - Initial creation.  V E R Y  B E T A.
-- 05062019 - Kevin Barlett, Microsoft - Temp logic below.  And now more B E T A version feeling than the original.
-- ===============================================================================================
--	
DECLARE @ComplianceTypeID INT
DECLARE @OSid smallint
DECLARE @ORGxml XML
--declare @ComplianceType varchar(256)
--declare @osname varchar(128)
--set @osname = '2012R2'
--set @ComplianceType = 'WindowsServerMS'
SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = @OSname)
SET @ComplianceTypeID = (SELECT ComplianceTYpeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
--SET @OSid = (SELECT OSid FROM PowerSTIG.targettypeos WHERE OSname = '2012R2')
--SET @ComplianceTypeID = (SELECT ComplianceTYpeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = 'WindowsServerMS')
--
--//////////////////////////
-- Temporary workaround to allow looser use of the TargetTypeOS.  This logic should be removed during an upcoming iteration.
--//////////////////////////
		IF @ComplianceType IN ('DotNetFramework','Firefox','WindowsFirewall','IISServer','IISSite','Word2013','Excel2013','PowerPoint2013','Outlook2013','OracleJRE','InternetExplorer','WindowsDefender','SqlServer2012Database','SqlServer2012Instance','SqlServer2016Instance')
		--
			BEGIN
				SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = 'ALL')
			END
		--
		IF @ComplianceType IN ('WindowsClient')
		--
			BEGIN
				SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = '10')
			END
--//////////////////////////
--
--//////////////////////////
IF NOT EXISTS
	(SELECT TOP 1 
		OrgRepoID 
	FROM 
		PowerSTIG.OrgSettingsRepo R  
			JOIN PowerSTIG.ComplianceTypesInfo I
				ON R.TypesInfoID = I.TypesInfoID
	WHERE 
		I.ComplianceTypeID = @ComplianceTypeID)
	--
	BEGIN
		SET @ORGxml = (SELECT  TOP 1
			--@ComplianceTYpe,
			I.OrgValue as '@fullversion'
		FROM  
			PowerSTIG.ComplianceTypesInfo I

		WHERE
			I.ComplianceTypeID = @ComplianceTypeID
			AND
			I.OSid = @OSid
		FOR  XML PATH('OrganizationalSettings'))


		 --------------------------------------------------
 -- Return results
 --------------------------------------------------
		SELECT @OrgXML AS ORGxml
 END
	
------------------------------------------------
------------------------------------------------
------------------------------------------------
IF EXISTS
	(SELECT TOP 1 
		OrgRepoID 
	FROM 
		PowerSTIG.OrgSettingsRepo R  
			JOIN PowerSTIG.ComplianceTypesInfo I
				ON R.TypesInfoID = I.TypesInfoID
	WHERE 
		I.ComplianceTypeID = @ComplianceTypeID)
		--
BEGIN
	
	SET @ORGxml = (
		SELECT  TOP 1
			--@ComplianceTYpe,
			I.OrgValue  AS '@fullversion'
	--
			,( SELECT 
					R.Finding AS '@id',
					R.OrgValue AS '@value'
				FROM
					PowerSTIG.OrgSettingsRepo R
					JOIN
						PowerSTIG.ComplianceTypesInfo I
							ON R.TypesInfoID = I.TypesInfoID
				WHERE
					I.ComplianceTypeID = @ComplianceTypeID

			FOR  XML PATH('OrganizationalSetting'),TYPE)
--, ROOT('OrganizationalSettings'))

		FROM  
			PowerSTIG.OrgSettingsRepo R
				LEFT OUTER JOIN
					PowerSTIG.ComplianceTypesInfo I
						ON R.TypesInfoID = I.TypesInfoID
		WHERE
			I.ComplianceTypeID = @ComplianceTypeID
			AND
			I.OSid = @OSid
 FOR  XML PATH('OrganizationalSettings'))
 --,ROOT('OrganizationalSettings')
 --------------------------------------------------
 -- Return results
 --------------------------------------------------
		SELECT @OrgXML AS ORGxml
 END
 GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_ImportOrgSettingsXML 
-- ==================================================================
:setvar CREATE_PROC "sproc_ImportOrgSettingsXML"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_ImportOrgSettingsXML
				@OrgFilePath varchar(384) = NULL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04112019 - Kevin Barlett, Microsoft - Initial creation.  V E R Y  B E T A.
-- ===============================================================================================
--
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @Path nvarchar(2000)
DECLARE @SQLcmd nvarchar(2000)
DECLARE @OrgSettingFile nvarchar(1000)
DECLARE @FileNamesID smallint
DECLARE @OrgSettingFullPath nvarchar(2000)
DECLARE @Technology varchar(128)
--
	IF @OrgFilePath IS NULL
		BEGIN
			SET @OrgFilePath = (SELECT ConfigSetting FROM PowerSTIG.ComplianceConfig WHERE ConfigProperty = 'ORGsettingXML')
		END
--------------------------------------------------------
SET @StepName = 'Purge existing ORG setting data'
--------------------------------------------------------
--

	BEGIN TRY
		DELETE FROM PowerSTIG.OrgSettingsRepo
		DELETE FROM PowerSTIG.ComplianceTypesInfo
	
			--
			SET @StepMessage = 'Existing ORG setting data purged.'
			SET @StepAction = 'DELETE'
			--
			EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
			

	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error purging existing ORG setting data.  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
--
-- Create working tables
--
	DROP TABLE IF EXISTS #OrgSettingFileNames
	DROP TABLE IF EXISTS #ImportOrgFile
	--
	CREATE TABLE #OrgSettingFileNames 
		(FileNamesID smallint IDENTITY(1,1)
		,FileNames nvarchar(1000) NULL
		,Depth smallint NULL
		,isFile BIT NULL)
	--
	CREATE TABLE #ImportOrgFile
		(ImportID INT IDENTITY(1,1) PRIMARY KEY,
		XMLData XML,
		--LoadedDateTime DATETIME,
		OrgSettingFile nvarchar(1000) NULL,
		OrgVersion varchar(10) NULL,
		Technology varchar(128) NULL)
--------------------------------------------------------
SET @StepName = 'Gather the file names as specified in @OrgFilePath and insert as BLOBs'
--------------------------------------------------------
	BEGIN TRY

			
	INSERT INTO #OrgSettingFileNames (FileNames,Depth,isFile)
		EXEC xp_DirTree @OrgFilePath,1,1
--
-- Insert ORG files as BLOBs
--
WHILE EXISTS (SELECT TOP 1 FileNamesID FROM #OrgSettingFileNames WHERE isFile = 1 AND FileNames LIKE '%.org.default.xml')
	BEGIN
		
		SET @FileNamesID = (SELECT TOP 1 FileNamesID FROM #OrgSettingFileNames WHERE isFile = 1 AND FileNames LIKE '%.org.default.xml')
		SET @OrgSettingFile = (SELECT FileNames FROM #OrgSettingFileNames WHERE FileNamesID = @FileNamesID)
		SET @OrgSettingFullPath = (SELECT @OrgFilePath+'\'+FileNames FROM #OrgSettingFileNames WHERE FileNamesID = @FileNamesID)

		SET @SQLcmd = 'INSERT INTO #ImportOrgFile (XMLData,OrgSettingFile,OrgVersion,Technology)
							SELECT CONVERT(XML, BulkColumn) AS BulkColumn,'''+@OrgSettingFile+''',-1,''Tech''
							FROM OPENROWSET(BULK '''+@OrgSettingFullPath+''', SINGLE_BLOB) AS x;'
		--PRINT @SQLcmd
		EXEC (@SQLcmd)
		--
		--
		--
			UPDATE #OrgSettingFileNames
			SET isFile = 0
			WHERE FileNamesID = @FileNamesID
		END
		--
			SET @StepMessage = 'ORG setting XML files successfully loaded.'
			SET @StepAction = 'INSERT'
			--
			EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction

--
-- Retrieve OrganizationalSetting version
-- This is somewhat kludge currently given inconsistency in ORG file's version attribute
--
			UPDATE #ImportOrgFile 
			SET OrgVersion =  (CASE
				WHEN tbl.col.value('(.//@Version)[1]', 'varchar(10)') IS NOT NULL THEN tbl.col.value('(.//@Version)[1]', 'varchar(10)') --AS OrgVersion
				WHEN tbl.col.value('(.//@fullversion)[1]', 'varchar(10)') IS NULL THEN tbl.col.value('(.//@version)[1]', 'varchar(10)') --AS OrgVersion
				WHEN tbl.col.value('(.//@version)[1]', 'varchar(10)') IS NULL THEN tbl.col.value('(.//@fullversion)[1]', ' varchar(10)') --AS OrgVersion
				
			END  )


		FROM 
			#ImportOrgFile xt
		CROSS APPLY 
			XMLdata.nodes('/OrganizationalSettings') tbl(col)
--
-- Retrieve technology
--
	UPDATE #ImportOrgFile
	SET Technology = 
 
	LEFT(OrgSettingFile,LEN(OrgSettingFile) - CHARINDEX('-',REVERSE(OrgSettingFile),1))
	FROM #ImportOrgFile

--
-- Retrieve highest rev of org setting file per technology
--
	DROP TABLE IF EXISTS #CurrentOrgSettingFile
	--
	SELECT * INTO #CurrentOrgSettingFile FROM (
		SELECT
			ImportID,
				Technology,
				--@Path+'\'+OrgSettingFile AS FullOrgSettingPath,
				OrgSettingFile,
				OrgVersion,
				ROW_NUMBER() OVER(PARTITION BY Technology ORDER BY OrgVersion desc) AS RowNum
		FROM
			#ImportOrgFile

			) T
		WHERE
			T.RowNum = 1
--
-- Update ComplianceTypes with OrgSettingVersion
--
	--UPDATE PowerSTIG.ComplianceTypes
	--SET 
	-- NEED SANITY CHECK.  DO I NEED TO MAP ORG SETTINGS + FINDING
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error loading ORG setting XML files.  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
--------------------------------------------------------
SET @StepName = 'Hydrate ComplianceTypesInfo'
--------------------------------------------------------
BEGIN TRY
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsServerDC'
			AND
			O.OSname = '2012R2'
			AND
			F.Technology = 'WindowsServer-2012R2-DC'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsServerDC'
			AND
			O.OSname = '2016'
			AND
			F.Technology = 'WindowsServer-2016-DC'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsServerMS'
			AND
			O.OSname = '2016'
			AND
			F.Technology = 'WindowsServer-2016-MS'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsServerMS'
			AND
			O.OSname = '2012R2'
			AND
			F.Technology = 'WindowsServer-2012R2-MS'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsClient'
			AND
			O.OSname = '10'
			AND
			F.Technology = 'WindowsClient-10'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'DotNetFramework'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'DotNetFramework-4'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'Firefox'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'FireFox-All'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'InternetExplorer'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'InternetExplorer-11'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'Excel2013'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-Excel2013'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'Outlook2013'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-Outlook2013'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'PowerPoint2013'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-PowerPoint2013'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'IISServer'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'IISServer-8.5'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'IISSite'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'IISSite-8.5'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'OracleJRE'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'OracleJRE-8'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'Word2013'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-Word2013'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsDNSServer'
			AND
			O.OSname = '2012R2'
			AND
			F.Technology = 'WindowsDnsServer-2012R2'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsDNSServer'
			AND
			O.OSname = '2016'
			AND
			F.Technology = 'WindowsDnsServer-2016'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsFirewall'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'WindowsFirewall-All'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'WindowsDefender'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'WindowsDefender-All'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'SqlServer2012Database'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'SqlServer-2012-Database'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'SqlServer2012Instance'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'SqlServer-2012-Instance'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'SqlServer2016Instance'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'SqlServer-2016-Instance'
	------------
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
		FROM 
			PowerSTIG.ComplianceTypes T
				,PowerSTIG.TargetTypeOS O
					,#CurrentOrgSettingFile F
		WHERE 
			T.ComplianceType = 'SqlServer2016Database'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'SqlServer-2016-Database'
	--
	SET @StepMessage = 'ComplianceTypesInfo successfully hydrated.'
	SET @StepAction = 'INSERT'
	--
	EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error hydrating ComplianceTypesInfo.  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
--
SET @StepName = 'Parse contents of org settings file per technology'
--
BEGIN TRY
WHILE EXISTS (SELECT RowNum FROM #CurrentOrgSettingFile WHERE RowNum = 1)
	BEGIN
		SET @Technology = (SELECT TOP 1 Technology FROM #CurrentOrgSettingFile WHERE RowNum = 1)
			INSERT INTO PowerSTIG.OrgSettingsRepo
				(TypesInfoID,Finding,OrgValue)
			SELECT
				I.TypesInfoID,
				tbl.col.value('(.//@id)[1]', 'nvarchar(10)') AS Finding
				,tbl.col.value('(.//@value)[1]', 'nvarchar(2000)') AS OrgValue

			FROM 
				PowerSTIG.ComplianceTypesInfo I,
					#ImportOrgFile xt
		CROSS APPLY 
			XMLdata.nodes('/OrganizationalSettings /*') tbl(col)
		WHERE
			xt.ImportID IN (SELECT ImportID FROM #CurrentOrgSettingFile WHERE Technology = @Technology)
			AND
			I.OrgSettingAlias = @technology
	--
	--
	--
		UPDATE #CurrentOrgSettingFile
		SET RowNum = 0
		WHERE Technology = @technology
	END
	--
	SET @StepMessage = 'ORG setting files successfully parsed.'
	SET @StepAction = 'INSERT'
	--
	EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error parsing ORG setting files.  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
--
-- Cleanup
--
	DROP TABLE IF EXISTS #CurrentOrgSettingFile
	DROP TABLE IF EXISTS #ImportOrgFile
	DROP TABLE IF EXISTS #OrgSettingFileNames
 GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_AddOrgSetting 
-- ==================================================================
:setvar CREATE_PROC "sproc_AddOrgSetting"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_AddOrgSetting
			@ComplianceType varchar(256),
			@OSname varchar(256),
			@Finding varchar(128),
			@OrgValue varchar(4000)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04112019 - Kevin Barlett, Microsoft - Initial creation.
-- Examples:
-- EXEC PowerSTIG.sproc_AddOrgSetting @ComplianceType='DotNetFramework',@OSname='ALL',@Finding='V-66666',@OrgValue='This is a new ORG setting for DotNetFramework.  There are many ORG settings but this one belongs to DotNetFramework.'
-- ===============================================================================================
--
DECLARE @ComplianceTypeID INT
DECLARE @OSid smallint
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = @OSname)
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)

--
SET @StepName =  'Validate @Finding format'
--
SET @Finding = LTRIM(RTRIM(@Finding))
--
	IF @Finding NOT LIKE '[V-,0-9]'
		AND
		@Finding NOT LIKE '[V-,0-9,.a-z]'
		AND
		LEN(@Finding) < 5
	BEGIN
		SET @StepMessage = 'The value '+@Finding+' does not adhere to known STIG identifiers (e.g. V-1234 or V-12345.a).  Please validate.'
		PRINT @StepMessage
		SET @StepAction = 'ERROR'
		--
		EXEC PowerSTIG.sproc_InsertScanLog
						@LogEntryTitle = @StepName
						,@LogMessage = @StepMessage
						,@ActionTaken = @StepAction
		SET NOEXEC ON
	END
--------------------------------------------------------
SET @StepName = 'Add ORG setting'
--------------------------------------------------------
BEGIN TRY
			INSERT INTO PowerSTIG.OrgSettingsRepo
				(TypesInfoID,
				Finding,
				OrgValue)
			SELECT
				I.TypesInfoID,
				@Finding,
				@OrgValue
			FROM
				PowerSTIG.ComplianceTypesInfo I
			WHERE
				I.ComplianceTypeID = @ComplianceTypeID
				AND
				I.OSid = @OSid
			
	SET @StepMessage = 'New ORG setting successfully added to PowerSTIG.OrgSettingsRepo, OrgRepoID='+CAST(SCOPE_IDENTITY()AS varchar(25))+'.'
	SET @StepAction = 'INSERT'
	--
	EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error adding ORG setting.  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
 GO
 
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
/*
-- ==================================================================
-- PowerStig.sproc_ResetTargetRoles 
-- ==================================================================
:setvar CREATE_PROC "sproc_ResetTargetRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_ResetTargetRoles
			@TargetComputer varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- Examples:
-- EXEC powerstig.sproc_ResetTargetRoles @targetcomputer='SQLtest003'
-- ===============================================================================================
--
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @TargetComputerID INT
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
-- -------------------------------
-- Reset all compliance types to 0
-- -------------------------------
SET @StepName = 'Compliance type reset for specific target'
--
	BEGIN TRY
		UPDATE 
			PowerSTIG.TargetTypeMap
		SET
			isRequired = 0
		WHERE
			TargetComputerID = @TargetComputerID
		--
		SET @StepMessage = ('Compliance types reset for target: ['+@TargetComputer+'].')
		SET @StepAction = 'UPDATE'
		--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
				   ,@LogMessage = @StepMessage
				   ,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
		SET @ErrorMessage  = ERROR_MESSAGE()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState    = ERROR_STATE()
		--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
		--
		SET @StepMessage = 'Error encountered resetting compliance types for: ['+@TargetComputer+'].  Captured error info: '+@ErrorMessage+'  Please validate.'
		SET @StepAction = 'ERROR'
		PRINT @StepMessage
				--
		EXEC PowerSTIG.sproc_InsertScanLog
			@LogEntryTitle = @StepName
		   ,@LogMessage = @StepMessage
		   ,@ActionTaken = @StepAction
		RETURN
	END CATCH
GO

-- ==================================================================
-- PowerStig.sproc_GetActiveServersRoleCount 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetActiveServersRoleCount"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetActiveServersRoleCount] 
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	SELECT DISTINCT
		TargetComputer,
		COUNT(isRequired) AS RoleCount
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
	WHERE
		T.isActive = 1
		AND
		M.isRequired = 1
	GROUP BY
		TargetComputer,isRequired
	ORDER BY
		TargetComputer
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO

-- ==================================================================
-- PowerStig.sproc_ComplianceTrendByTargetRole 
-- ==================================================================
:setvar CREATE_PROC "sproc_ComplianceTrendByTargetRole"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_ComplianceTrendByTargetRole]
					@TargetComputer varchar(256)
							
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @TargetComputerID INT
--declare @TargetComputer varchar(255)
--set @TargetComputer = 'SQLtest003'
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
--
	DROP TABLE IF EXISTS #RecentScan

-- =======================================================
-- Find the most recent scan for each target + compliance type combination
-- =======================================================
			SELECT * INTO #RecentScan FROM (
		SELECT
				T.TargetComputer,
			Y.ComplianceType,
			--TargetComputerID,
			--ComplianceTypeID,
			S.ScanID,
			S.ScanGUID,

			ROW_NUMBER() OVER(PARTITION BY L.ComplianceTypeID,L.TargetComputerID ORDER BY L.LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog L
				JOIN PowerSTIG.ComplianceTargets T
					ON L.TargetComputerID = T.TargetComputerID
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON L.ComplianceTypeID = Y.ComplianceTypeID
			JOIN PowerSTIG.Scans S
				ON S.ScanID = L.ScanID

		WHERE
			L.TargetComputerID = @TargetComputerID
			) T
		WHERE
			T.RowNum = 1
-- =======================================================
-- Return results
-- =======================================================
	SELECT
		ComplianceType,
		COUNT(R.inDesiredState) AS NumberOfCompliantFindings,
		S.ScanDate
	FROM
		PowerSTIG.Scans S
			JOIN
				PowerSTIG.FindingRepo R
			ON
				S.ScanID = R.ScanID
			JOIN
				PowerSTIG.ComplianceTypes T
			ON
				T.ComplianceTypeID = R.ComplianceTypeID

	WHERE
		R.InDesiredState = 1
		AND
		R.TargetComputerID = @TargetComputerID
		AND
		R.ScanID IN (SELECT ScanID FROM #RecentScan)
	GROUP BY
		T.ComplianceType,R.inDesiredState,S.ScanDate
--
-- Cleanup
--
	DROP TABLE IF EXISTS #RecentScan
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
*/
-- ==================================================================
-- PowerStig.sproc_GetComplianceTypes
-- ==================================================================
:setvar CREATE_PROC "sproc_GetComplianceTypes"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetComplianceTypes
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
	SELECT
		T.ComplianceType,
		T.ComplianceTypeID
	FROM
		PowerSTIG.ComplianceTypes T
	ORDER BY
		T.ComplianceTypeID
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_GetOrgSettingsByRole 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetOrgSettingsByRole"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetOrgSettingsByRole
			@ComplianceType varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ComplianceTypeID INT
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
 SELECT
	T.ComplianceType,
	R.Finding AS RuleID,
	F.FindingText,
	R.OrgValue
FROM
	PowerSTIG.OrgSettingsRepo R
		JOIN
			PowerSTIG.ComplianceTypesInfo I
		ON
			R.TypesInfoID = I.TypesInfoID
		JOIN
			PowerSTIG.ComplianceTypes T
		ON
			T.ComplianceTypeID = I.ComplianceTypeID
		LEFT OUTER JOIN
			PowerSTIG.Finding F
		ON
			F.Finding = R.Finding
WHERE
	T.ComplianceTypeID = @ComplianceTypeID
ORDER BY
	R.Finding
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_GetRSpages 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetRSpages"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetRSpages
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
	SELECT
		PageName,
		ReportName
	FROM
		PowerSTIG.RSpages
	WHERE
		isActive = 1
	ORDER BY
		ReportOrder,PageName
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_GetLogDates 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLogDates"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetLogDates
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
	SELECT DISTINCT 
		DATEADD(day, 0, DATEDIFF(day, 0, LogTS)) AS LogDate
	FROM 
		PowerSTIG.ScanLog
	ORDER BY
		LogDate DESC
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_GetDetailedScanResults 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetDetailedScanResults"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetDetailedScanResults
					        @TargetComputer varchar(256),
							@ComplianceType varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 04242019 - Kevin Barlett, Microsoft - Initial creation.
-- Examples:
-- EXEC PowerSTIG.sproc_GetDetailedScanResults @TargetComputer='sqltest003',@ComplianceType='WindowsServerMS'
-- ===============================================================================================
DECLARE @TargetComputerID INT
DECLARE @ComplianceTypeID INT
--declare @targetcomputer varchar(256)
--set @TargetComputer = 'sqltest003'
--declare @compliancetype varchar(256)
--set @compliancetype = 'WindowsServerMS'
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
--
-- ----------------------------------------
-- Find most recent scan
-- ----------------------------------------
	DROP TABLE IF EXISTS #RecentScan
		--
		CREATE TABLE #RecentScan (
			TargetComputerID INT NULL,
			ComplianceTypeID INT NULL,
			ScanID INT NULL,
			RowNum INT NULL)
	--
	INSERT INTO #RecentScan (TargetComputerID,ComplianceTypeID,ScanID,RowNum)
	SELECT 
		TargetComputerID,
		ComplianceTypeID,
		ScanID,
		RowNum
	FROM (
		SELECT
			TargetComputerID,
			ComplianceTypeID,
			ScanID,
			ROW_NUMBER() OVER(PARTITION BY ComplianceTypeID ORDER BY LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog
		WHERE
			TargetComputerID = @TargetComputerID
			) T
		WHERE
			T.RowNum = 1
-- ----------------------------------------
--
-- ----------------------------------------
	SELECT
		R.InDesiredState
		,F.Finding AS RuleID
		,S.Severity
		,S.Title
		,S.RawString AS CheckDescription
		--,S.FixText
		,L.LastComplianceCheck
	FROM
		PowerSTIG.FindingRepo R
			JOIN
				PowerSTIG.Finding F
			ON 
				R.FindingID = F.FindingID
			LEFT OUTER JOIN 
				PowerSTIG.StigTextRepo S
			ON 
				F.Finding = S.RuleID
			JOIN 
				PowerSTIG.ComplianceTypes T
			ON 
				T.ComplianceTypeID = R.ComplianceTypeID
			JOIN
				PowerSTIG.ComplianceCheckLog L
			ON 
				L.ScanID = R.ScanID
	WHERE 
			R.ScanID = (SELECT MAX(ScanID) FROM #RecentScan WHERE ComplianceTypeID = @ComplianceTypeID)
			AND
			R.TargetComputerID = @TargetComputerID
			AND
			T.ComplianceTypeID = @ComplianceTypeID

-- ----------------------------------------
-- Cleanup
-- ----------------------------------------
	DROP TABLE IF EXISTS #RecentScan
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_UpdateCKLtargetInfo 
-- ==================================================================
:setvar CREATE_PROC "sproc_UpdateCKLtargetInfo"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_UpdateCKLtargetInfo
					@TargetComputer varchar(256),
					@IPv4address varchar(15)=NULL,
					@IPv6address varchar(45)=NULL,
					@MACaddress varchar(17)=NULL,
					@FQDN varchar(384)=NULL
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 05062019 - Kevin Barlett, Microsoft - Initial creation.
-- Examples:
-- exec powerstig.SPROC_updateckltargetinfo @targetcomputer='SQLtest003',@ipv4address='10.0.0.2',@fqdn='SQLtest003.FOURTHCOFFEE.COM'
-- ===============================================================================================
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
--
SET @StepName = 'Update ComplianceTarget information'
	BEGIN TRY
		UPDATE
			PowerSTIG.ComplianceTargets
		SET
			IPv4address = @IPv4address,
			IPv6address = @IPv6address,
			MACaddress = @MACaddress,
			FQDN = @FQDN
		WHERE
			TargetComputer = LTRIM(RTRIM(@TargetComputer))
			--
		SET @StepMessage = 'Information successfully update for target computer ['+@TargetComputer+'].'
		SET @StepAction = 'UPDATE'
			--
		EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--
			SET @StepMessage = 'Error updating information for target computer ['+@TargetComputer+'].  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- PowerStig.sproc_GetCKLtargetInfo 
-- ==================================================================
:setvar CREATE_PROC "sproc_GetCKLtargetInfo"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetCKLtargetInfo
				@TargetComputer varchar(256)
AS
SET NOCOUNT ON
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
-- Purpose:
-- Revisions:
-- 05062019 - Kevin Barlett, Microsoft - Initial creation.
-- Examples:
-- 
-- ===============================================================================================

		SELECT
			TargetComputer,
			IPv4address,
			MACaddress,
			FQDN
		FROM
			PowerSTIG.ComplianceTargets
		WHERE
			TargetComputer = LTRIM(RTRIM(@TargetComputer))
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
PRINT 'End create procedures'
-- ===============================================================================================
-- ===============================================================================================
-- ===============================================================================================
DECLARE @Timestamp DATETIME
SET @Timestamp = (GETDATE())
--
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerStigScan database object deployment end - '+CONVERT(VARCHAR,GETDATE(), 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'