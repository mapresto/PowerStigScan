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
DECLARE @VersionNotes varchar(MAX)
SET @UpdateVersion = 504
SET @VersionNotes = 'Add temporal table feature to OrgSettingsRepo to guard against accidental changes or deletions and prepare for future enhancements | New proc: sproc_UpdateOrgSetting to facilitate updates to a specific ORG value | Support for Office2016 | Drop tables: Finding, StigTextRepo | Drop check_ActionTaken constraint on ScanLog.  You will not be missed. | Added logic to sproc_ImportOrgSettingsXML to preserve non-default settings | sproc_GenerateCKLfile bug fix | sproc_ImportSTIGxml logic addition for RoleAlias to support CKL generation | Update to sproc_ProcessFindings to support StigName column | New column ComplianceTypes.StigName | New column CheckListInfo.RoleAlias | Update CKLfilePath in ComplianceConfig'
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
	IF NOT EXISTS (SELECT UpdateVersion FROM PowerSTIG.DBversion WHERE UpdateVersion = @UpdateVersion)
		BEGIN
    		INSERT INTO PowerSTIG.DBversion (UpdateVersion,VersionTS,isActive,VersionNotes)
           		VALUES
              		(@UpdateVersion,GETDATE(),0,@VersionNotes)
		END
	ELSE
		BEGIN
			UPDATE
				PowerSTIG.DBversion
			SET
				VersionTS = GETDATE(),
					VersionNotes = @VersionNotes
			WHERE
				UpdateVersion = @UpdateVersion
		END
-- ===============================================================================================
-- ===============================================================================================
--
-- Cleanup from last release
DROP TABLE IF EXISTS dbo.BBB2E8D2E65B480BAB3BCA670DA245F0
GO
-- ==================================================================
-- Add RoleAlias to ComplianceTypesInfo
-- ==================================================================
IF NOT EXISTS (
		SELECT [name] FROM sys.columns 
			WHERE  object_id = OBJECT_ID(N'[PowerSTIG].[ComplianceTypesInfo]') 
				AND [name] = 'RoleAlias')
	BEGIN
		ALTER TABLE PowerSTIG.ComplianceTypesInfo ADD RoleAlias varchar(128) NULL
	END
GO
-- ==================================================================
-- Add isDefaultValue to OrgSettingsRepo table
-- ==================================================================
IF NOT EXISTS (
		SELECT [name] FROM sys.columns 
			WHERE  object_id = OBJECT_ID(N'[PowerSTIG].[OrgSettingsRepo]') 
				AND [name] = 'isDefaultValue')
	BEGIN
		ALTER TABLE PowerSTIG.OrgSettingsRepo ADD isDefaultValue BIT DEFAULT(1) NOT NULL
	END
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
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_UpdateOrgSetting]
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
				OrgValue = @OrgValue,
					isDefaultValue=0
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
-- Add RoleAlias to CheckListInfo
-- ==================================================================
IF NOT EXISTS (
		SELECT [name] FROM sys.columns 
			WHERE  object_id = OBJECT_ID(N'[PowerSTIG].[CheckListInfo]') 
				AND [name] = 'RoleAlias')
	BEGIN
		ALTER TABLE PowerSTIG.CheckListInfo ADD RoleAlias varchar(128) NULL
	END
GO

-- ==================================================================
-- [PowerSTIG].[sproc_ImportSTIGxml]
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_ImportSTIGxml]
				@CKLfilePath varchar(384)=NULL
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
-- 06182019 - Kevin Barlett, Microsoft - Major revision to support using the CKL files as the source of STIG vulnerability and text data.
-- Use examples:
-- EXEC PowerSTIG.sproc_ImportSTIGxml SET @CKLfilePath = 'C:\Program Files\WindowsPowerShell\Modules\PowerStigScan\2.0.0.0\Common\CKL'
-- ====================================================================================
SET NOCOUNT ON
--
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @Path nvarchar(2000)
DECLARE @SQLcmd nvarchar(2000)
DECLARE @Header varchar(75) = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
DECLARE @TemplateFile varchar(384)
DECLARE @ImportID smallint
DECLARE @FileNamesID smallint
DECLARE @CKLFullPath nvarchar(2000)
DECLARE @Technology varchar(128)
DECLARE @CheckListInfoID varchar(25)
DECLARE @CKLfile varchar(1000)
DECLARE @Col nvarchar(max)
DECLARE @ReleaseVersion varchar(6)
----------------------------------------------------------
-- Hydrate @CKLfilePath if not passed
----------------------------------------------------------
	IF @CKLfilePath IS NULL
		BEGIN
			SET @CKLfilePath = (SELECT ConfigSetting FROM PowerSTIG.ComplianceConfig WHERE ConfigProperty = 'CKLfilePath')
		END
----------------------------------------------------------
-- Create working tables
----------------------------------------------------------

	DROP TABLE IF EXISTS ##__CKLFileNames
	DROP TABLE IF EXISTS ##__ImportCKLFile
	DROP TABLE IF EXISTS ##__CKL_XML 
	--
	CREATE TABLE ##__CKLFileNames 
		(FileNamesID smallint IDENTITY(1,1)
		,FileNames nvarchar(1000) NULL
		,Depth smallint NULL
		,isFile BIT NULL)
	--
	CREATE TABLE ##__ImportCKLFile
		(ImportID INT IDENTITY(1,1) PRIMARY KEY,
		XMLData varchar(MAX),
		--LoadedDateTime DATETIME,
		CKLFile nvarchar(1000) NULL,
		CKLversion decimal(18,2) NULL,
		Technology varchar(128) NULL,
		isProcessed BIT DEFAULT(0))
	--		
	CREATE TABLE ##__CKL_XML
		(ImportID int,
		CheckListFileName varchar(384),
		CheckList XML,
		isProcessed BIT DEFAULT(0))
----------------------------------------------------------
SET @StepName = 'Hydrate ##__CKLFileNames with CKL file names'
----------------------------------------------------------
	BEGIN TRY
		INSERT INTO ##__CKLFileNames (FileNames,Depth,isFile)
		EXEC xp_DirTree @CKLfilePath,1,1
	END TRY
	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			SET @StepMessage = 'Error hydrating ##__CKLFileNames with CKL file names.  Captured error info: '+@ErrorMessage+'  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
				RETURN
	END CATCH
----------------------------------------------------------
SET @StepName = 'Import CKL XML files'
----------------------------------------------------------
		--
		-- First, import the CKL file into a table
		--
WHILE EXISTS (SELECT TOP 1 FileNamesID FROM ##__CKLFileNames WHERE isFile = 1 AND FileNames LIKE '%.ckl')
	BEGIN
		BEGIN TRY
			SET @FileNamesID = (SELECT TOP 1 FileNamesID FROM ##__CKLFileNames WHERE isFile = 1 AND FileNames LIKE '%.ckl')
			SET @CKLfile = (SELECT FileNames FROM ##__CKLFileNames WHERE FileNamesID = @FileNamesID)
			SET @CKLFullPath = (SELECT @CKLFilePath+'\'+FileNames FROM ##__CKLFileNames WHERE FileNamesID = @FileNamesID)

			SET @SQLcmd = 'INSERT INTO ##__ImportCKLFile (XMLData,CKLfile,CKLversion,Technology,isProcessed)
								SELECT BulkColumn,'''+@CKLfile+''',-1,''Tech'',0
								FROM OPENROWSET(BULK '''+@CKLFullPath+''', SINGLE_BLOB) AS x;'
			--PRINT @SQLcmd
			EXEC (@SQLcmd)

		END TRY
		BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			SET @StepMessage = 'Error importing CKL files.  Captured error info: '+@ErrorMessage+'  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
				RETURN
		END CATCH
----------------------------------------------------------
SET @StepName = 'Flatten the STIG_INFO node data'
----------------------------------------------------------
		--
		-- Second, flatten the STIG_INFO data
		--
		BEGIN TRY		
						SET @ImportID = (SELECT TOP 1 ImportID FROM ##__ImportCKLFile WHERE isProcessed = 0)

						INSERT INTO ##__CKL_XML 
							(
							ImportID,
							CheckListFileName,
							CheckList,
							isProcessed
							)
						SELECT 
							ImportID,
							CKLfile,
							CONVERT(XML,REPLACE(XMLData,@Header,'')),
							0 AS isProcessed
						FROM 
							##__ImportCKLFile
						WHERE
							ImportID = @ImportID

						--DECLARE @CKLfile XML
						--SET @CKLfile = (SELECT CONVERT(XML,REPLACE(XMLData,@Header,''))
						--FROM #ImportOrgFile WHERE ImportID = @ImportID)
						--
						--DECLARE @ID int
						--SET @ID = (SELECT TOP 1 ID FROM ##__CKL_XML WHERE isProcessed = 0)
						--
							DROP TABLE IF EXISTS ##__CKLinfo
							DROP TABLE IF EXISTS #CKLheaderParse
							--
						SELECT 
								dense_rank() over(order by ImportID, I.N) as ID,
							   F.N.value('(SID_NAME/text())[1]', 'varchar(max)') as [Name],
							   F.N.value('(SID_DATA/text())[1]', 'varchar(max)') as [Value],
							   G.N.value('(ROLE/text())[1]', 'varchar(max)') AS [ROLE],
							   G.N.value('(ASSET_TYPE/text())[1]', 'varchar(max)') AS [ASSET_TYPE],
							   G.N.value('(HOST_NAME/text())[1]', 'varchar(max)') AS [HOST_NAME],
							   G.N.value('(HOST_IP/text())[1]', 'varchar(max)') AS [HOST_IP],
							   G.N.value('(HOST_MAC/text())[1]', 'varchar(max)') AS [HOST_MAC],
							   G.N.value('(HOST_FQDN/text())[1]', 'varchar(max)') AS [HOST_FQDN],
							   G.N.value('(TECH_AREA/text())[1]', 'varchar(max)') AS [TECH_AREA],
							   G.N.value('(TARGET_KEY/text())[1]', 'varchar(max)') AS [TARGET_KEY],
							   G.N.value('(WEB_OR_DATABASE/text())[1]', 'varchar(max)') AS [WEB_OR_DATABASE],
							   G.N.value('(WEB_DB_SITE/text())[1]', 'varchar(max)') AS [WEB_DB_SITE],
							   G.N.value('(WEB_DB_INSTANCE/text())[1]', 'varchar(max)') AS [WEB_DB_INSTANCE]
						INTO 
							#CKLheaderParse
						FROM 
							##__CKL_XML as T
						CROSS APPLY 
							T.CheckList.nodes('//CHECKLIST/STIGS/iSTIG/STIG_INFO') as I(N)
						CROSS APPLY 
							I.N.nodes('SI_DATA') as F(N)
						CROSS APPLY
							T.CheckList.nodes('//CHECKLIST/ASSET') AS G(N)

		--
		-- Create new table from flattened XML nodes
		--
				SELECT @Col = 
						  (
					SELECT DISTINCT ','+quotename(Name)
					FROM
						#CKLheaderParse
						  FOR XML PATH(''), TYPE
						  ).value('substring(text()[1], 2)', 'nvarchar(max)')

						SET @SQLcmd = 'SELECT '+@Col+',ROLE,ASSET_TYPE,HOST_NAME,HOST_IP,HOST_MAC,HOST_FQDN,TECH_AREA,TARGET_KEY,WEB_OR_DATABASE,WEB_DB_SITE,WEB_DB_INSTANCE 
										INTO ##__CKLinfo
									FROM #CKLheaderParse
									PIVOT (MAX(Value) for Name in ('+@Col+')) as P'

						--PRINT @SQLcmd
						EXEC (@SQLcmd)
		END TRY
			BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			SET @StepMessage = 'Error flattening the STIG_INFO node data.  Captured error info: '+@ErrorMessage+'  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
				RETURN
		END CATCH
----------------------------------------------------------
SET @StepName = 'Hydrate CheckListInfo with CKL header metadata'
----------------------------------------------------------
		--
		-- Calculate ReleaseVersion
		--
		SET @ReleaseVersion = (SELECT [version]+'.'+substring(releaseinfo, X2.Position + 1, X3.Position - X2.Position - 1) AS [ReleaseVersion]		
										FROM
										##__CKLinfo
											CROSS APPLY (SELECT (CHARINDEX(':', releaseinfo))) as X1(Position)
												CROSS APPLY (SELECT (CHARINDEX(' ', releaseinfo, X1.Position+1))) as X2(Position)
													CROSS APPLY (SELECT (CHARINDEX(' ', releaseinfo, X2.Position+1))) as X3(Position))

		--
		-- Third, hydrate ChecklistInfo table with CKL file metadata
		--
		BEGIN TRY

				INSERT INTO PowerSTIG.CheckListInfo
						(Version,Classification,CustomName,StigID,Description,FileName,ReleaseInfo,ReleaseVersion,Title,UUID,Notice,Source,ROLE,ASSET_TYPE,HOST_NAME,HOST_IP,HOST_MAC,HOST_FQDN,TECH_AREA,TARGET_KEY,WEB_OR_DATABASE,WEB_DB_SITE,WEB_DB_INSTANCE,CKLfile)
				SELECT
						--TemplateFile
						[Version]
						,[Classification]
						,[CustomName]
						,[StigID]
						,[Description]
						,[FileName]
						,[ReleaseInfo]
						,@ReleaseVersion AS [ReleaseVersion]
						--,[version]+'.'+substring(releaseinfo, X2.Position + 1, X3.Position - X2.Position - 1) AS [ReleaseVersion]
						,[Title]
						,[UUID]
						,[Notice]
						,[Source]
						,[ROLE]
						,[ASSET_TYPE]
						,[HOST_NAME]
						,[HOST_IP]
						,[HOST_MAC]
						,[HOST_FQDN]
						,[TECH_AREA]
						,[TARGET_KEY]
						,[WEB_OR_DATABASE]
						,[WEB_DB_SITE]
						,[WEB_DB_INSTANCE]
						,CONVERT(XML,REPLACE(XMLdata,@Header,'')) AS [CKLfile]
				FROM
					##__CKLinfo I,
						##__ImportCKLFile
				WHERE NOT EXISTS
					(
					(SELECT 1 FROM PowerSTIG.CheckListInfo C WHERE C.ReleaseVersion = @ReleaseVersion AND C.StigID = I.StigID AND C.[filename] = I.[filename])
					)
				--
				-- This is painful.  Workaround to account for lack of naming standards across files and tools.  Used to map PowerSTIG compliance types to the proper CKL template.
				--
				UPDATE 
					PowerSTIG.CheckListInfo 
				SET 
					RoleAlias = (SELECT REPLACE(LEFT([FileName], CHARINDEX('_V',[FileName])-1),'_',''))

	END TRY

	BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			SET @StepMessage = 'Error hydrating CheckListInfo with CKL header metadata.  Captured error info: '+@ErrorMessage+'  Please validate.'
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
	-- Retrieve the CheckListInfoID
	--
	SET @CheckListInfoID = (SELECT CAST(SCOPE_IDENTITY() AS varchar(25)))
	--print @checklistinfoid
----------------------------------------------------------
SET @StepName = 'Flatten the vulnerability attributes in the CKL'
----------------------------------------------------------
IF @CheckListInfoID IS NOT NULL
	BEGIN
		--
		-- Fourth, flatten the vulnerability attributes in the CKL
		--
	BEGIN TRY
						DROP TABLE IF EXISTS #CKLattributeParse
						DROP TABLE IF EXISTS ##__CKLattributes
						--
								SELECT 
									dense_rank() over(order by ImportID, I.N) as ID,
							   F.N.value('(VULN_ATTRIBUTE/text())[1]', 'varchar(max)') as Name,
							   F.N.value('(ATTRIBUTE_DATA/text())[1]', 'varchar(max)') as Value,
							   I.N.value('(STATUS/text())[1]', 'varchar(max)') AS [Status],
							   I.N.value('(FINDING_DETAILS/text())[1]', 'varchar(max)') AS [FindingDetails],
							   I.N.value('(COMMENTS/text())[1]', 'varchar(max)') AS [Comments],
							   I.N.value('(SEVERITY_OVERRIDE/text())[1]', 'varchar(max)') AS [SeverityOverride],
							   I.N.value('(SEVERITY_JUSTIFICATION/text())[1]', 'varchar(max)') AS [SeverityJustification]
						INTO
							#CKLattributeParse
						FROM 
							##__CKL_XML AS T
						  CROSS APPLY
							T.Checklist.nodes('//VULN') as I(N)
						  CROSS APPLY
							I.N.nodes('STIG_DATA') as F(N)
						  CROSS APPLY
							I.N.nodes('STATUS') as G(N)

						SELECT @Col = 
						  (
						  SELECT DISTINCT ','+quotename(Name)--,[Status]
						  FROM #CKLattributeParse
						  FOR XML PATH(''), type
						  ).value('substring(text()[1], 2)', 'nvarchar(max)')

						SET @SQLcmd = 'SELECT '+@Col+',Status,FindingDetails,Comments,SeverityOverride,SeverityJustification,'+@CheckListInfoID+' AS CheckListInfoID 
										INTO
												##__CKLattributes
										FROM
											#CKLattributeParse
										PIVOT (max(Value) for Name in ('+@Col+')) as P'


						--print @sqlcmd
						EXEC (@SQLcmd)
		END TRY
		BEGIN CATCH
			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			SET @StepMessage = 'Error flattening the vulnerability attributes in the CKL.  Captured error info: '+@ErrorMessage+'  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
				RETURN
		END CATCH
----------------------------------------------------------
SET @StepName = 'Hydrate CheckListAttributes with flattened vulnerability data'
----------------------------------------------------------
		--
		-- Fifth, hydrate the CheckListAttributes
		--
		BEGIN TRY

						INSERT INTO PowerSTIG.CheckListAttributes 
							(
								CheckListInfoID,
								VulnerabilityNum,
								Severity,
								GroupTitle,
								RuleID,
								RuleVersion,
								RuleTitle,
								VulnerabilityDiscussion,
								IAcontrols,
								CheckContent,
								FixText,
								FalsePositives,
								FalseNegatives,
								Documentable,
								Mitigations,
								PotentialImpact,
								ThirdPartyTools,
								MitigationControl,
								Responsibility,
								SecurityOverrideGuidance,
								CheckContentRef,
								VulnWeight,
								Class,
								STIGref,
								TargetKey,
								CCIref,
								Status,
								FindingDetails,
								Comments,
								SeverityOverride,
								SeverityJustification
							)
						SELECT
							@CheckListInfoID AS CheckListInfoID,
							[Vuln_Num],
							[Severity],
							[Group_Title],
							[Rule_ID],
							[Rule_Ver],
							[Rule_Title],
							[Vuln_Discuss],
							[IA_Controls],
							[Check_Content],
							[Fix_Text],
							[False_Positives],
							[False_Negatives],
							[Documentable],
							[Mitigations],
							[Potential_Impact],
							[Third_Party_Tools],
							[Mitigation_Control],
							[Responsibility],
							[Security_Override_Guidance],
							[Check_Content_Ref],
							[Weight],
							[Class],
							[STIGRef],
							[TargetKey],
							[CCI_REF],
							[Status],
							[FindingDetails],
							[Comments],
							[SeverityOverride],
							[SeverityJustification]
						FROM
							##__CKLattributes

	END TRY

	BEGIN CATCH

			SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			--RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			SET @StepMessage = 'Error hydrating CheckListAttributes.  Captured error info: '+@ErrorMessage+'  Please validate.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
				RETURN
		END CATCH
END

		--
		-- Set files as is processed and other WHILE loop housekeeping
		--

				UPDATE
					##__CKL_XML
				SET
					isProcessed = 1
				WHERE
					ImportID = @ImportID
				--
				--
				--UPDATE
				--	##__ImportCKLFile 
				--SET 
				--	isProcessed = 1 
				--WHERE
				--	ImportID = @ImportID
				--
				--
				UPDATE 
					##__CKLFileNames
				SET
					isFile = 0
				WHERE
					FileNamesID = @FileNamesID
				--
				--
				TRUNCATE TABLE ##__CKL_XML
				--
				TRUNCATE TABLE ##__ImportCKLFile
END

-- -------------------------------
-- Cleanup
-- -------------------------------
	DROP TABLE IF EXISTS ##__CKL_XML
	DROP TABLE IF EXISTS ##__ImportCKLFile
	DROP TABLE IF EXISTS ##__CKLFileNames
GO
-- ==================================================================
-- sproc_ImportOrgSettingsXML
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
-- 07092019 - Kevin Barlett, Microsoft - Support for preserving ORG data through XML imports.
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
SET @StepName = 'Preserve non-default ORG setting data'
--------------------------------------------------------
	BEGIN TRY
		DROP TABLE IF EXISTS ##__PreserveORGsettings
		--
		CREATE TABLE ##__PreserveORGsettings 
			(PreserveORGid smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
			Finding varchar(128) NOT NULL,
			OrgValue varchar(4000) NOT NULL)
		--
		INSERT INTO 
			##__PreserveORGsettings (Finding,OrgValue)
		SELECT
			Finding
			,OrgValue
		FROM
			PowerSTIG.OrgSettingsRepo
		WHERE
			isDefaultValue = 0

		--
		SET @StepMessage = 'Preserve non-default ORG setting data.'
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
			SET @StepMessage = 'Error preserving existing ORG setting data.  Captured error info: '+@ErrorMessage+'.'
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
	SET Technology = LEFT(OrgSettingFile,LEN(OrgSettingFile) - CHARINDEX('-',REVERSE(OrgSettingFile),1))
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindows2012and2012R2DCSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindowsServer2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindowsServer2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindows2012and2012R2MSSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindows10STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSDotNetFramework4-0STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMozillaFireFoxSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSIE11STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSExcel2013STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSExcel2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSOutlook2013STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMicrosoftOutlook2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSPowerPoint2013' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMicrosoftPowerPoint2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSIIS8-5ServerSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSIIS8-5SiteSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UOracleJRE8WindowsSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWord2013STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMicrosoftWord2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindows2012ServerDNSSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindowsServer2016STIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UWindowsFirewallSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSWindowsDefenderAntivirusSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSSQLServer2012DatabaseSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSSQLServer2012InstanceSTIG' AS RoleAlias
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
	INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
		SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile,'UMSSQLServer2016InstanceSTIG' AS RoleAlias
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
	--INSERT INTO PowerSTIG.ComplianceTypesInfo(ComplianceTypeID,OSid,OrgValue,OrgSettingAlias,OrgSettingFile,RoleAlias)
	--	SELECT T.ComplianceTypeID,O.OSid,F.OrgVersion,F.Technology,F.OrgSettingFile
	--	FROM 
	--		PowerSTIG.ComplianceTypes T
	--			,PowerSTIG.TargetTypeOS O
	--				,#CurrentOrgSettingFile F
	--	WHERE 
	--		T.ComplianceType = 'SqlServer-2016-Database'
	--		AND
	--		O.OSname = 'ALL'
	--		AND
	--		F.Technology = 'SqlServer-2016-Database'
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
--------------------------------------------------------
SET @StepName = 'Replace preserved ORG settings'
--------------------------------------------------------
	BEGIN TRY
		--
		UPDATE 
			PowerSTIG.OrgSettingsRepo
		SET
			OrgValue = P.OrgValue,
				isDefaultValue = 0
		FROM
			PowerSTIG.OrgSettingsRepo O
				JOIN
					##__PreserveORGsettings P
						ON O.Finding = P.Finding

		--
		SET @StepMessage = 'Replace preserved ORG setting data.'
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
			SET @StepMessage = 'Error replacing preserved ORG setting data.  Captured error info: '+@ErrorMessage+'.'
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
	DROP TABLE IF EXISTS ##__PreserveORGsettings
GO
-- ==================================================================
-- PowerStig.sproc_GenerateORGxml 
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GenerateORGxml]
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
		IF @ComplianceType IN ('DotNetFramework','Firefox','WindowsFirewall','IISServer','IISSite','Word2013','Excel2013','PowerPoint2013','Outlook2013','Word2016','Excel2016','PowerPoint2016','Outlook2016','OracleJRE','InternetExplorer','WindowsDefender','SqlServer-2012-Database','SqlServer-2012-Instance','SqlServer-2016-Instance')
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
-- ==================================================================
-- PowerStig.sproc_GenerateCKLfile
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GenerateCKLfile]
				@TargetComputer varchar(256),
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
-- 06182019 - Kevin Barlett, Microsoft - Initial creation.
-- Use examples:
-- EXEC PowerSTIG.sproc_GenerateCKLfile @STargetComputer = 'STIG',@TargetRole='InternetExplorer'
-- ====================================================================================
SET NOCOUNT ON
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @TargetComputerID INT
DECLARE @ComplianceTypeID smallint
DECLARE @Checklist XML
DECLARE @i        int           = 1
DECLARE @max      int           = 1
DECLARE @iSTIG    int           = 1
DECLARE @MaxiSTIG int           
DECLARE @VulnId   nvarchar(10)
DECLARE @Status varchar(25)
DECLARE @Comments nvarchar(MAX)
DECLARE @UpdatedComments nvarchar(MAX)
DECLARE @ImportID smallint
--DECLARE @RevMapVuln varchar(13)
DECLARE @CheckListInfoID INT
DECLARE @OSid smallint
--DECLARE @TargetComputer varchar(256)
--DECLARE @TargetRole varchar(256)
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @TargetRole)
SET @OSid = 9999
--SET @TargetComputerID = 1
--SET @ComplianceTypeID = 19
--
		--
		IF @TargetRole IN ('DotNetFramework','Firefox','WindowsFirewall','IISServer','IISSite','Word2013','Excel2013','PowerPoint2013','Outlook2013','Word2016','Excel2016','PowerPoint2016','Outlook2016','OracleJRE','InternetExplorer','WindowsDefender','SqlServer-2012-Database','SqlServer-2012-Instance','SqlServer-2016-Instance')
		--
			BEGIN
				SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = 'ALL')
			END
		--
		IF @TargetRole IN ('WindowsClient')
		--
			BEGIN
				SET @OSid = (SELECT OSid FROM PowerSTIG.TargetTypeOS WHERE OSname = '10')
			END
		--
		IF @OSid = 9999
		--
			BEGIN
				SET @OSid = (SELECT OSid FROM PowerSTIG.ComplianceTargets WHERE TargetComputerID = @TargetComputerID)
			END
-- ----------------------------------------
-- Find most recent scan
-- ----------------------------------------
--
	DROP TABLE IF EXISTS #RecentScan
	DROP TABLE IF EXISTS #ResultsForPivot
	DROP TABLE IF EXISTS ##__ResultsCompare
--

SELECT * INTO #RecentScan FROM 
         (
         SELECT  M.*, ROW_NUMBER() OVER (PARTITION BY TargetComputerID,ComplianceTypeID,ScanSourceID ORDER BY LastComplianceCheck DESC) RN
         FROM    PowerSTIG.ComplianceSourceMap M
         ) T
		WHERE
			T.RN = 1
-- ----------------------------------------
-- Hydrate #ResultsForPivot
-- ----------------------------------------
	
	SELECT 
		R.InDesiredState
		,O.ScanSource
		,F.VulnerabilityNum AS RuleID
		,L.LastComplianceCheck
	INTO
		#ResultsForPivot
	FROM
			#RecentScan C
		JOIN
			PowerSTIG.FindingRepo R
		ON
			C.ScanID = R.ScanID
		JOIN 
			PowerSTIG.Scans S
		ON 
			R.ScanID = S.ScanID
		JOIN
			PowerSTIG.ScanSource O
		ON
			O.ScanSourceID = S.ScanSourceID
		JOIN
			PowerSTIG.CheckListAttributes F
		ON
			F.CheckListAttributeID = R.CheckListAttributeID
		JOIN
			PowerSTIG.ComplianceCheckLog L
		ON
			S.ScanID = L.ScanID
		WHERE
			R.ScanID IN (SELECT scanid FROM #RecentScan)
		AND
				R.TargetComputerID = @TargetComputerID
		AND
				R.ComplianceTypeID = @ComplianceTypeID

	GROUP BY				
		R.InDesiredState
		,O.ScanSource
		,F.VulnerabilityNum
		,L.LastComplianceCheck
	ORDER BY
		VulnerabilityNum
-- ----------------------------------------
-- Return results
-- ----------------------------------------
		SELECT 
			*
			INTO ##__ResultsCompare
		FROM
				(
				SELECT
					RuleID,
					CAST(InDesiredState AS tinyint) AS InDesiredState,
					ScanSource
				FROM 
					#ResultsForPivot
				) 
					AS SourceTable PIVOT(AVG([InDesiredState]) FOR ScanSource IN([POWERSTIG],[SCAP])) AS PivotTable;

-- ----------------------------------------
-- Load CKL to temp table for manipulation
-- ----------------------------------------
					SET @CheckListInfoID =	(
											SELECT
												MAX(I.CheckListInfoID)
											FROM 
												PowerSTIG.CheckListInfo I
											JOIN
												PowerSTIG.ComplianceTypesInfo O
											ON
												I.RoleAlias = O.RoleAlias
											JOIN
												PowerSTIG.ComplianceTypes T
											ON
												T.ComplianceTypeID = O.ComplianceTypeID
											WHERE
												T.ComplianceTypeID = @ComplianceTypeID
											AND 
												O.OSid = @OSid
											)
--
--
--
	SET @Checklist = (SELECT CKLfile FROM PowerSTIG.CheckListInfo WHERE CheckListInfoID = @CheckListInfoID)
	SET @MaxiSTIG = (SELECT @Checklist.value('count(/CHECKLIST/STIGS/iSTIG)', 'int'))
			--
			DROP TABLE IF EXISTS ##__CreateCKL
			CREATE TABLE ##__CreateCKL (CheckList XML NULL)
			--
			INSERT INTO ##__CreateCKL (CheckList) VALUES (@Checklist)


WHILE @iSTIG <= @MaxiSTIG

   BEGIN
         SET @i   = 1
         SET @max = (SELECT @Checklist.value('count(/CHECKLIST/STIGS/iSTIG[sql:variable("@iSTIG")]/VULN)', 'int'))

         WHILE @i <= @max
         BEGIN
            SELECT @VulnId = @Checklist.value('((/CHECKLIST/STIGS/iSTIG[sql:variable("@iSTIG")]/VULN[sql:variable("@i")]/STIG_DATA/ATTRIBUTE_DATA)[1]/text())[1]', 'nvarchar(10)')
-- ----------------------------------------
-- Update the Status
-- ----------------------------------------
			SET @Status = 	(SELECT
					[STATUS] = CASE
						WHEN T.PowerSTIG = 0 AND T.SCAP = 0 THEN 'Open'
						WHEN T.PowerSTIG = 0 AND T.SCAP = 1 THEN 'NotAFinding'
						WHEN T.PowerSTIG = 1 AND T.SCAP = 1 THEN 'NotAFinding'
						WHEN T.PowerSTIG = 0 AND T.SCAP IS NULL THEN 'Open'
						WHEN T.PowerSTIG = 1 AND T.SCAP IS NULL THEN 'NotAFinding'
						WHEN T.PowerSTIG = 1 AND T.SCAP = 0 THEN 'NotAFinding'
						WHEN T.PowerSTIG IS NULL AND T.SCAP = 0 THEN 'Open'
						WHEN T.PowerSTIG IS NULL AND T.SCAP = 1 THEN 'NotAFinding'
						END
			FROM
					##__ResultsCompare T
			WHERE
				T.RuleID = @VulnId)
			--
			-- STIGs with no check - need to improve this in a future release, like so many other things
			--
			IF NOT EXISTS
				(SELECT RuleID FROM ##__ResultsCompare WHERE RuleID = @VulnId)
					BEGIN
						SET @Status = 'Not_Reviewed'
					END
	
		--
		UPDATE
			##__CreateCKL
        SET 
			checklist.modify('replace value of ((/CHECKLIST/STIGS/iSTIG[sql:variable("@iSTIG")]/VULN[sql:variable("@i")]/STATUS)[1]/text())[1] with sql:variable("@Status")')
        WHERE
			checklist.exist('((/CHECKLIST/STIGS/iSTIG[sql:variable("@iSTIG")]/VULN[sql:variable("@i")]/STATUS)[1]/text())[1]') = 1
		--AND
		--	ImportID = @ImportID
		
-- ----------------------------------------
-- Update the Comments
-- ----------------------------------------
				SET @Comments = (SELECT
						[COMMENTS] = CASE
							WHEN T.PowerSTIG = 0 AND T.SCAP = 0 THEN 'Results from PowerSTIG and SCAP'
							WHEN T.PowerSTIG = 0 AND T.SCAP = 1 THEN 'Results from SCAP'
							WHEN T.PowerSTIG = 1 AND T.SCAP = 1 THEN 'Results from PowerSTIG and SCAP'
							WHEN T.PowerSTIG = 0 AND T.SCAP IS NULL THEN 'Results from PowerSTIG'
							WHEN T.PowerSTIG = 1 AND T.SCAP IS NULL THEN 'Results from PowerSTIG'
							WHEN T.PowerSTIG = 1 AND T.SCAP = 0 THEN 'Results from PowerSTIG'
							WHEN T.PowerSTIG IS NULL AND T.SCAP = 0 THEN 'Results from SCAP'
							WHEN T.PowerSTIG IS NULL AND T.SCAP = 1 THEN 'Results from SCAP'
							END
					FROM
						##__ResultsCompare T
					WHERE
						T.RuleID = @VulnId)
			--
           UPDATE
				##__CreateCKL
           SET 
				checklist.modify('insert text{sql:variable("@Comments")} into (/CHECKLIST/STIGS/iSTIG[sql:variable("@iSTIG")]/VULN[sql:variable("@i")]/COMMENTS)[1]')

           SET @i += 1

         END

      SET @iSTIG += 1

   END
-- ----------------------------------------
-- Return the CKL
-- ----------------------------------------
	SELECT
		CheckList
	FROM
		##__CreateCKL
-- ----------------------------------------
-- Cleanup
-- ----------------------------------------
DROP TABLE IF EXISTS ##__CreateCKL
DROP TABLE IF EXISTS ##__ResultsCompare
DROP TABLE IF EXISTS #ResultsForPivot
GO
-- ==================================================================
-- sproc_ProcessFindings
-- ==================================================================
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
--DECLARE @ScanVersion varchar(8)
--DECLARE @RevMapVuln varchar(25)
DECLARE @OSid smallint
DECLARE @CheckListInfoID int
--------------------------------------------------------
SET @StepName = 'Retrieve new GUIDs'
--------------------------------------------------------
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
		WHERE 
			I.[GUID] = @GUID
				--
				-- Do Logging
				--
				SET @StepMessage = 'Processing GUID: '+@GUID
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
			SET @StepMessage = 'Error inserting unprocessed GUIDs into Scans table.  Captured error info: '+@ErrorMessage+'.'
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
SET @StepName = 'Hydrate ComplianceType'
--------------------------------------------------------
	------BEGIN TRY
	------	INSERT INTO 
	------		PowerSTIG.ComplianceTypes(ComplianceType,isActive)
	------	SELECT DISTINCT
	------		StigType,
	------		1 AS isActive
	------	FROM 
	------		PowerSTIG.FindingImport
	------	WHERE
	------		StigType NOT IN (SELECT ComplianceType FROM PowerSTIG.ComplianceTypes)


	------			SET @StepMessage = 'Insert new ComplianceTypes (roles) into ComplianceType table.'
	------			SET @StepAction = 'INSERT'
	------			--
	------			EXEC PowerSTIG.sproc_InsertScanLog
	------				@LogEntryTitle = @StepName
	------				,@LogMessage = @StepMessage
	------				,@ActionTaken = @StepAction
	------END TRY
	------BEGIN CATCH
	------		SET @ErrorMessage  = ERROR_MESSAGE()
	------		SET @ErrorSeverity = ERROR_SEVERITY()
	------		SET @ErrorState    = ERROR_STATE()
	------		--
	------		SET @StepMessage = 'Error inserting new compliance types (roles) into ComplianceTypes table.  Captured error info: '+@ErrorMessage+'.'
	------		SET @StepAction = 'ERROR'
	------		PRINT @StepMessage
	------				--
	------		EXEC PowerSTIG.sproc_InsertScanLog
	------			@LogEntryTitle = @StepName
	------		   ,@LogMessage = @StepMessage
	------		   ,@ActionTaken = @StepAction
	------		RETURN
	------END CATCH
--
-- Retrieve ScanID
--
		SET @OSid = (SELECT OSid FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = (SELECT DISTINCT TargetComputer FROM PowerSTIG.FindingImport WHERE [GUID] = @GUID))
		SET @ScanID = (SELECT ScanID FROM PowerSTIG.Scans WHERE [ScanGUID] = @GUID AND isProcessed = 0)

		--					
		-- So much technical debt to retrieve the CheckListInfoID.  Displeased with this.
		--
		SET @CheckListInfoID = 
						(		
								SELECT
									MAX(N.CheckListInfoID)
								FROM
									PowerSTIG.FindingImport I
								JOIN
									PowerSTIG.ComplianceTypes T
								ON
									I.StigType = T.ComplianceType
								JOIN
									PowerSTIG.ComplianceTypesInfo O
								ON
									T.ComplianceTypeID = O.ComplianceTypeID
										AND
											I.ScanVersion = O.OrgValue
								JOIN
									PowerSTIG.CheckListInfo N
								ON
									O.RoleAlias = N.RoleAlias
								WHERE
									I.[GUID] = @GUID
						)
--------------------------------------------------------
SET @StepName = 'Hydrate FindingRepo'
--------------------------------------------------------
	BEGIN TRY
				INSERT INTO
					PowerSTIG.FindingRepo (TargetComputerID,CheckListAttributeID,InDesiredState,ComplianceTypeID,ScanID)
				SELECT
					T.TargetComputerID,
					F.CheckListAttributeID,
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
							PowerSTIG.CheckListAttributes F
								ON I.VulnID = F.VulnerabilityNum
						JOIN
							PowerSTIG.CheckListInfo O
								ON O.CheckListInfoID = F.CheckListInfoID
						JOIN
							PowerSTIG.ComplianceTypes C
								ON C.ComplianceType = I.StigType
				WHERE
					[GUID] = @GUID
					AND
					F.CheckListInfoID = @CheckListInfoID
				
				--
				-- Set the ScanID as Processed
				--
					UPDATE
						PowerSTIG.Scans
					SET
						isProcessed = 1
					WHERE
						ScanID = @ScanID
				--
				SET @StepMessage = 'Process raw scan data from FindingImport to Finding table.'
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
			SET @StepMessage = 'Error processing raw data from FindingImport to FindingRepo tables.  Captured error info: '+@ErrorMessage+'.'
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
SET @StepName = 'Update ComplianceCheckLog'
--------------------------------------------------------
	BEGIN TRY
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

				SET @StepMessage = 'Update ComplianceCheckLog table with datetime per target computer and compliance type.'
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
			SET @StepMessage = 'Error updating ComplianceCheckLog table.  Captured error info: '+@ErrorMessage+'.'
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
SET @StepName = 'Update ComplianceTargets'
--------------------------------------------------------
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

				SET @StepMessage = 'Update ComplianceTargets.LastComplianceCheck with current datetime.'
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
			SET @StepMessage = 'Error updating ComplianceTargets table with LastComplianceCheck.  Captured error info: '+@ErrorMessage+'.'
			SET @StepAction = 'ERROR'
			PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
			RETURN
	END CATCH
-- =======================================================
-- Cleanup
-- =======================================================
	DROP TABLE IF EXISTS #NewComplianceTarget
GO
-- ==================================================================
-- Update CKLfilePath in ComplianceConfig
-- ==================================================================
UPDATE 
	PowerSTIG.ComplianceConfig 
SET 
	ConfigSetting = 'C:\Program Files\WindowsPowerShell\Modules\PowerStigScan\2.1.0.0\Common\CKL'
WHERE
	ConfigProperty = 'CKLfilePath'
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
