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
SET @UpdateVersion = 504
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
--
-- Cleanup from last release
DROP TABLE IF EXISTS dbo.BBB2E8D2E65B480BAB3BCA670DA245F0
GO
-- ==================================================================
-- Add temporal feature to OrgSettingsRepo
-- ==================================================================
--
-- Make backup just in case
--
SELECT
	*
INTO 
	dbo.C2DE41B069764ED3A132E421721BCB4A
FROM
	PowerSTIG.OrgSettingsRepo
GO
--
ALTER TABLE PowerSTIG.OrgSettingsRepo ADD SysStartTime datetime2
--
ALTER TABLE PowerSTIG.OrgSettingsRepo ADD SysEndTime datetime2
GO
--
UPDATE PowerSTIG.OrgSettingsRepo
	SET 
		SysStartTime = GETDATE(),
		SysEndTime = '9999-12-31 23:59:59.9999999'
GO
--
ALTER TABLE PowerSTIG.OrgSettingsRepo ALTER COLUMN SysStartTime datetime2 NOT NULL
GO
--
ALTER TABLE PowerSTIG.OrgSettingsRepo ALTER COLUMN SysEndTime datetime2 NOT NULL
GO
--
ALTER TABLE PowerSTIG.OrgSettingsRepo ADD PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime)
GO
--
ALTER TABLE PowerSTIG.OrgSettingsRepo SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = PowerSTIG.OrgSettingsRepoHistory));
GO
-- ==================================================================
-- PowerStig.sproc_UpdateOrgSetting 
-- ==================================================================
CREATE OR ALTER   PROCEDURE [PowerSTIG].[sproc_UpdateOrgSetting]
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
-- 06202019 - Kevin Barlett, Microsoft - Initial creation.
-- Examples:
-- EXEC [PowerSTIG].[sproc_UpdateOrgSetting] @Finding='V-63619',@OrgValue='xSuperDuperPowerUserNotAdminThough'
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
--SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
--------------------------------------------------------
SET @StepName =  'Validate @Finding format'
--------------------------------------------------------
SET @Finding = LTRIM(RTRIM(@Finding))
--
	IF @Finding NOT LIKE '[V-,0-9]'
		AND
		@Finding NOT LIKE '[V-,0-9,.a-z]'
		AND
		LEN(@Finding) < 5
		OR
		@Finding NOT IN (SELECT Finding FROM PowerSTIG.OrgSettingsRepo)
	BEGIN
		SET @StepMessage = 'The value '+@Finding+' does not adhere to known STIG identifiers (e.g. V-1234 or V-12345.a) or does not currently have an associated OrgSetting.  Please validate.'
		PRINT @StepMessage
		SET @StepAction = 'ERROR'
		--
		EXEC PowerSTIG.sproc_InsertScanLog
						@LogEntryTitle = @StepName
						,@LogMessage = @StepMessage
						,@ActionTaken = @StepAction
		 --
		 -- Bail out of the update.  Issue identified.
		 --
					SELECT 8675309 AS UpdateError;
					--THROW 8675309, @StepMessage--'The value '+@Finding+' does not adhere to known STIG identifiers (e.g. V-1234 or V-12345.a) or does not currently have an associated OrgSetting.  Please validate.', 1
					THROW 8675309, @StepMessage, 1
	END

--------------------------------------------------------
SET @StepName = 'Update ORG setting'
--------------------------------------------------------
BEGIN TRY
			UPDATE
				PowerSTIG.OrgSettingsRepo
			SET
				OrgValue = @OrgValue
			WHERE
				Finding = @Finding

		
	SET @StepMessage = 'ORG setting successfully updated for finding: '+@Finding+'.'
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
			SET @StepMessage = 'Error updating ORG setting.  Captured error info: '+@ErrorMessage+'.  Please investigate.'
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
-- Support for Office2016 
-- ==================================================================
IF NOT EXISTS (SELECT ComplianceType FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = 'Excel2016')
	BEGIN
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Excel2016',1)
	END
GO
IF NOT EXISTS (SELECT 1 FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = 'Outlook2016')
	BEGIN
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Outlook2016',1)
	END
GO
IF NOT EXISTS (SELECT 1 FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = 'PowerPoint2016')
	BEGIN
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('PowerPoint2016',1)
	END
GO
IF NOT EXISTS (SELECT 1 FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = 'Word2016')
	BEGIN
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Word2016',1)
	END

GO
-- ==================================================================
-- PowerStig.sproc_ImportOrgSettingsXML support for Office2016
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_ImportOrgSettingsXML]
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
			T.ComplianceType = 'WindowsServer-DC'
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
			T.ComplianceType = 'WindowsServer-DC'
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
			T.ComplianceType = 'WindowsServer-MS'
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
			T.ComplianceType = 'WindowsServer-MS'
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
			T.ComplianceType = 'FireFox'
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
			T.ComplianceType = 'Excel2016'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-Excel2016'
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
			T.ComplianceType = 'Outlook2016'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-Outlook2016'
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
			T.ComplianceType = 'PowerPoint2016'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-PowerPoint2016'
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
			T.ComplianceType = 'Word2016'
			AND
			O.OSname = 'ALL'
			AND
			F.Technology = 'Office-Word2016'
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
			T.ComplianceType = 'SqlServer-2012-Database'
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
			T.ComplianceType = 'SqlServer-2012-Instance'
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
			T.ComplianceType = 'SqlServer-2016-Instance'
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
			T.ComplianceType = 'SqlServer-2016-Database'
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
-- ==================================================================
-- Execute PowerStig.sproc_ImportOrgSettingsXML to re-hydrate ORG settings to include Office2016
-- ==================================================================
EXEC PowerStig.sproc_ImportOrgSettingsXML
GO

-- ==================================================================
-- Drop unused tables
-- ==================================================================
DROP TABLE IF EXISTS PowerSTIG.Finding
GO
DROP TABLE IF EXISTS PowerSTIG.StigTextREpo
GO
-- ==================================================================
-- Remove ActionTaken constraint on PowerSTIG.ScanLog
-- ==================================================================
IF (OBJECT_ID('PowerSTIG.check_ActionTaken', 'C') IS NOT NULL)
	BEGIN
		ALTER TABLE [PowerSTIG].[ScanLog] DROP CONSTRAINT [check_ActionTaken]
	END
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
--
			UPDATE
				PowerSTIG.DBversion
			SET 
				VersionNotes = 'Add temporal table feature to OrgSettingsRepo to guard against accidental changes or deletions and prepare for future enhancements | New proc: sproc_UpdateOrgSetting to facilitate updates to a specific ORG value | Support for Office2016 | Drop tables: Finding, StigTextRepo | Drop check_ActionTaken constraint on ScanLog.  You will not be missed.'
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
