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
SET @UpdateVersion = 503
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

INSERT INTO PowerSTIG.ComplianceConfig
	(ConfigProperty
	,ConfigSetting
	,ConfigNote)
	VALUES
	('CKLfilePath'
	,'C:\Program Files\WindowsPowerShell\Modules\PowerStigScan\2.0.0.0\Common\CKL'
	,'Location for empty or template STIG checklist (CKL) files.')

GO
-- ==================================================================
-- [PowerSTIG].[CheckListInfo]
-- ==================================================================
--drop table if exists [PowerSTIG].[CheckListInfo]
CREATE TABLE [PowerSTIG].[CheckListInfo](
	[CheckListInfoID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[Version] [varchar](50) NULL,
	[Classification] [varchar](50) NULL,
	[Customname] [varchar](500) NULL,
	[StigID] [varchar](255) NOT NULL,
	[Description] [varchar](500) NULL,
	[Filename] [varchar](255) NULL,
	[ReleaseInfo] [varchar](255) NOT NULL,
	[ReleaseVersion] varchar(6) NULL,
	[Title] [varchar](255) NULL,
	[uuid] [varchar](36) NULL,
	[Notice] [varchar](255) NULL,
	[Source] varchar(255) NULL,
	[ROLE] [varchar](255) NULL,
	[ASSET_TYPE] [varchar](255) NULL,
	[HOST_NAME] [varchar](255) NULL,
	[HOST_IP] [varchar](255) NULL,
	[HOST_MAC] [varchar](255) NULL,
	[HOST_FQDN] [varchar](255) NULL,
	[TECH_AREA] [varchar](255) NULL,
	[TARGET_KEY] [varchar](255) NULL,
	[WEB_OR_DATABASE] [varchar](255) NULL,
	[WEB_DB_SITE] [varchar](255) NULL,
	[WEB_DB_INSTANCE] [varchar](255) NULL,
	[CKLfile] XML NULL
) ON [PRIMARY]
GO
-- ==================================================================
-- [PowerSTIG].[CheckListAttributes]
-- ==================================================================
--drop table if exists [PowerSTIG].[CheckListAttributes]
CREATE TABLE [PowerSTIG].[CheckListAttributes](
	[CheckListAttributeID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[CheckListInfoID] [int] NOT NULL,
	[VulnerabilityNum] [varchar](25) NULL,
	[Severity] [varchar](6) NULL,
	[GroupTitle] [varchar](384) NULL,
	[RuleID] [varchar](25) NULL,
	[RuleVersion] [varchar](25) NULL,
	[RuleTitle] [varchar](2000) NULL,
	[VulnerabilityDiscussion] [varchar](max) NULL,
	[IAcontrols] [varchar](50) NULL,
	[CheckContent] [varchar](max) NULL,
	[FixText] [varchar](max) NULL,
	[FalsePositives] [varchar](256) NULL,
	[FalseNegatives] [varchar](256) NULL,
	[Documentable] [varchar](6) NULL,
	[Mitigations] [varchar](max) NULL,
	[PotentialImpact] [varchar](max) NULL,
	[ThirdPartyTools] [varchar](256) NULL,
	[MitigationControl] [varchar](256) NULL,
	[Responsibility] [varchar](50) NULL,
	[SecurityOverrideGuidance] [varchar](max) NULL,
	[CheckContentRef] [varchar](8) NULL,
	[VulnWeight] [varchar](8) NULL,
	[Class] [varchar](25) NULL,
	[STIGref] [varchar](256) NULL,
	[TargetKey] [int] NULL,
	[CCIref] [varchar](50) NULL,
	[Status] [varchar](25) NULL,
	[FindingDetails] [varchar](max) NULL,
	[Comments] [varchar](max) NULL,
	[SeverityOverride] [varchar](2000) NULL,
	[SeverityJustification] [varchar](2000) NULL)
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
					(SELECT 1 FROM PowerSTIG.CheckListInfo C WHERE C.ReleaseVersion = @ReleaseVersion AND C.StigID = I.StigID AND C.filename = I.filename)
					)
				--			SELECT 1 FROM PowerSTIG.vw_TargetTypeMap M WHERE I.TargetComputer = M.TargetComputer AND I.StigType = M.ComplianceType)
				--			select @releaseversion
				--			select
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
-- Execute PowerSTIG.sproc_ImportSTIGxml to hydrate CheckListInfo and CheckListAttributes tables
-- ==================================================================
		EXEC PowerSTIG.sproc_ImportSTIGxml
GO
-- ==================================================================
-- Alter PowerSTIG.FindingRepo
-- ==================================================================
--
DROP TABLE IF EXISTS PowerSTIG.BBB2E8D2E65B480BAB3BCA670DA245F0
GO
--
--
--
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ComplianceType', 'F') IS NOT NULL)
		BEGIN
			ALTER TABLE PowerSTIG.FindingRepo DROP CONSTRAINT [FK_FindingRepo_ComplianceType]
		END

GO
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_CheckListAttributeID', 'F') IS NOT NULL)
		BEGIN
			ALTER TABLE PowerSTIG.FindingRepo DROP CONSTRAINT [FK_FindingRepo_CheckListAttributeID]
		END
GO
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ScanID', 'F') IS NOT NULL)
		BEGIN
			ALTER TABLE PowerSTIG.FindingRepo DROP CONSTRAINT [FK_FindingRepo_ScanID]
		END
GO
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_TargetComputer', 'F') IS NOT NULL)
		BEGIN
			ALTER TABLE PowerSTIG.FindingRepo DROP CONSTRAINT [FK_FindingRepo_TargetComputer]
		END
GO
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_Finding', 'F') IS NOT NULL)
		BEGIN
			ALTER TABLE PowerSTIG.FindingRepo DROP CONSTRAINT [FK_FindingRepo_Finding]
		END
GO

--
--
--
ALTER TABLE PowerSTIG.FindingRepo ADD VulnerabilityNum varchar(13)
GO
--
--
--
UPDATE PowerSTIG.FindingRepo
	SET 
		VulnerabilityNum = F.Finding
FROM
	PowerSTIG.FindingRepo R
		JOIN
			PowerSTIG.Finding F
		ON
			R.FindingID = F.FindingID
GO
--
--
--
UPDATE PowerSTIG.FindingRepo
	SET 
		FindingID = A.CheckListAttributeID
FROM
	PowerSTIG.CheckListAttributes A
		JOIN
			PowerSTIG.FindingRepo R
		ON
			A.VulnerabilityNum = R.VulnerabilityNum
GO
--
--
--
ALTER TABLE PowerSTIG.FindingRepo DROP COLUMN VulnerabilityNum
GO
--
--
--
SELECT * 
		INTO BBB2E8D2E65B480BAB3BCA670DA245F0
FROM
		PowerSTIG.FindingRepo
GO
--
--
--
DROP TABLE IF EXISTS PowerSTIG.FindingRepo
GO
--
--
--
CREATE TABLE [PowerSTIG].[FindingRepo](
	[TargetComputerID] [int] NOT NULL,
	[CheckListAttributeID] INT NOT NULL,
	[InDesiredState] [bit] NOT NULL,
	[ComplianceTypeID] [int] NOT NULL,
	[ScanID] [int] NOT NULL
) ON [PRIMARY]
GO
--
--
--
INSERT INTO PowerSTIG.FindingRepo
		(TargetComputerID,CheckListAttributeID,InDesiredState,ComplianceTypeID,ScanID)
SELECT
		TargetComputerID,
		FindingID,
		InDesiredState,
		ComplianceTypeID,
		ScanID
FROM
		BBB2E8D2E65B480BAB3BCA670DA245F0
GO
--
--
--
ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_ComplianceType] FOREIGN KEY([ComplianceTypeID])
REFERENCES [PowerSTIG].[ComplianceTypes] ([ComplianceTypeID])
GO

ALTER TABLE [PowerSTIG].[FindingRepo] CHECK CONSTRAINT [FK_FindingRepo_ComplianceType]
GO

ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_CheckListAttributeID] FOREIGN KEY([CheckListAttributeID])
REFERENCES [PowerSTIG].[CheckListAttributes] ([CheckListAttributeID])
GO

ALTER TABLE [PowerSTIG].[FindingRepo] CHECK CONSTRAINT [FK_FindingRepo_CheckListAttributeID]
GO

ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_ScanID] FOREIGN KEY([ScanID])
REFERENCES [PowerSTIG].[Scans] ([ScanID])
GO

ALTER TABLE [PowerSTIG].[FindingRepo] CHECK CONSTRAINT [FK_FindingRepo_ScanID]
GO

ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_TargetComputer] FOREIGN KEY([TargetComputerID])
REFERENCES [PowerSTIG].[ComplianceTargets] ([TargetComputerID])
GO

ALTER TABLE [PowerSTIG].[FindingRepo] CHECK CONSTRAINT [FK_FindingRepo_TargetComputer]
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
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @TargetRole)
--SET @TargetComputerID = 1
--SET @ComplianceTypeID = 5
--
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
		PowerSTIG.FindingRepo R
			JOIN 
				PowerSTIG.Scans S
				ON 
				R.ScanID = S.ScanID
			JOIN
				PowerSTIG.ScanSource O
				on
				O.ScanSourceID = S.ScanSourceID
			JOIN
				PowerSTIG.CheckListAttributes F
				on
				F.CheckListAttributeID = R.CheckListAttributeID
			JOIN
				PowerSTIG.ComplianceCheckLog L
				ON
				S.ScanID = L.ScanID
			WHERE
				R.ScanID IN (select scanid from #RecentScan)
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
SET @Checklist = (SELECT CKLfile FROM PowerSTIG.CheckListInfo WHERE StigID = 'IE_11_STIG') --Need to pull the checklist file from CheckListInfo table AND pull the correct version
SET @MaxiSTIG = (SELECT @Checklist.value('count(/CHECKLIST/STIGS/iSTIG)', 'int'))
			--
			DROP TABLE IF EXISTS ##__CreateCKL
			create table ##__CreateCKL (CheckList XML NULL)
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
							WHEN T.PowerSTIG = 0 AND T.SCAP = 0 THEN 'Results from SCAP'
							WHEN T.PowerSTIG = 0 AND T.SCAP = 1 THEN 'Results from SCAP'
							WHEN T.PowerSTIG = 0 AND T.SCAP IS NULL THEN 'Results from PowerSTIG'
							WHEN T.PowerSTIG = 1 AND T.SCAP IS NULL THEN 'Results from PowerSTIG'
							WHEN T.PowerSTIG = 1 AND T.SCAP = 0 THEN 'Results from PowerSTIG'
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
-- [FK_CheckListAttributes_CheckListInfoID]
-- ==================================================================
ALTER TABLE [PowerSTIG].[CheckListAttributes]  WITH NOCHECK ADD CONSTRAINT [FK_CheckListAttributes_CheckListInfoID] FOREIGN KEY([CheckListInfoID])
REFERENCES [PowerSTIG].[CheckListInfo] ([CheckListInfoID])
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
DECLARE @RevMapVuln varchar(25)
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
		WHERE I.[GUID] NOT IN
			(SELECT ScanGUID FROM PowerSTIG.Scans)

				SET @StepMessage = 'Insert unprocessed GUIDs into Scans'
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
----------------------------------------------------------
--SET @StepName = 'Hydrate Finding'
----------------------------------------------------------
--	BEGIN TRY
--		INSERT INTO 
--			PowerSTIG.Finding(Finding)
--		SELECT DISTINCT
--			LTRIM(RTRIM(VulnID)) AS Finding
--		FROM 
--			PowerSTIG.FindingImport
--		WHERE
--			LTRIM(RTRIM(VulnID)) NOT IN (SELECT Finding FROM PowerSTIG.Finding)
--				--
--				SET @StepMessage = 'Insert new findings into Findings table'
--				SET @StepAction = 'INSERT'
--				--
--				EXEC PowerSTIG.sproc_InsertScanLog
--					@LogEntryTitle = @StepName
--					,@LogMessage = @StepMessage
--					,@ActionTaken = @StepAction
--	END TRY
--	BEGIN CATCH
--			SET @ErrorMessage  = ERROR_MESSAGE()
--			SET @ErrorSeverity = ERROR_SEVERITY()
--			SET @ErrorState    = ERROR_STATE()
--			--
--			SET @StepMessage = 'Error inserting new findings (STIGs) into Finding table.  Captured error info: '+@ErrorMessage+'.'
--			SET @StepAction = 'ERROR'
--			PRINT @StepMessage
--					--
--			EXEC PowerSTIG.sproc_InsertScanLog
--				@LogEntryTitle = @StepName
--			   ,@LogMessage = @StepMessage
--			   ,@ActionTaken = @StepAction
--			RETURN
--	END CATCH
--------------------------------------------------------
SET @StepName = 'Hydrate ComplianceType'
--------------------------------------------------------
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


				SET @StepMessage = 'Insert new ComplianceTypes (roles) into ComplianceType table.'
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
			SET @StepMessage = 'Error inserting new compliance types (roles) into ComplianceTypes table.  Captured error info: '+@ErrorMessage+'.'
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
SET @StepName = 'Hydrate FindingRepo'
--------------------------------------------------------
	BEGIN TRY

			WHILE EXISTS
				(SELECT TOP 1 ScanID FROM PowerSTIG.Scans WHERE [ScanGUID] = @GUID AND isProcessed = 0)
					BEGIN
						SET @ScanID = (SELECT TOP 1 ScanID FROM PowerSTIG.Scans WHERE [ScanGUID] = @GUID AND isProcessed = 0)
						--					
						-- Reverse engineer the Vulnerability to get the newest CheckListInfoID.  This is not the preferred solution, but, well, technical debt.
						--
						SET @RevMapVuln = (SELECT TOP 1 VulnID FROM PowerSTIG.FindingImport WHERE [GUID] = @GUID)
						SET @CheckListInfoID = (SELECT MAX(CheckListInfoID) AS CheckListInfoID FROM PowerSTIG.CheckListAttributes WHERE VulnerabilityNum = @RevMapVuln)
						--SET @ScanVersion = (SELECT TOP 1 ScanVersion FROM PowerSTIG.FindingImport WHERE [GUID] = @GUID)
						--
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
							PowerSTIG.ComplianceTypes C
								ON C.ComplianceType = I.StigType
						JOIN 
							PowerSTIG.Scans S
								ON I.[GUID] = S.ScanGUID
				WHERE
					S.ScanID = @ScanID
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
		END
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
-- Page compression on PowerSTIG.CheckListAttributes
-- ==================================================================
	ALTER TABLE PowerSTIG.CheckListAttributes REBUILD WITH (DATA_COMPRESSION = PAGE);
	GO
-- ==================================================================
-- PowerStig.sproc_GetDetailedScanResults 
-- ==================================================================
CREATE OR ALTER  PROCEDURE [PowerSTIG].[sproc_GetDetailedScanResults]
					        @TargetComputer varchar(256),
							@ComplianceType varchar(256),
							@ScanSource varchar(25)
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
-- PURPOSE: Returns detailed finding data for a specific target computer + compliance type (role) + scan source
-- REVISIONS:
-- 04242019 - Kevin Barlett, Microsoft - Initial creation.
-- 05212019 - Kevin Barlett, Microsoft - SCAP support
-- EXAMPLES:
-- EXEC PowerSTIG.sproc_GetDetailedScanResults @targetcomputer = 'fourthcoffeedc',@compliancetype='WindowsFirewall',@scansource = 'POWERSTIG'
-- ===============================================================================================
DECLARE @TargetComputerID INT
DECLARE @ScanSourceID smallint
DECLARE @ComplianceTypeID smallint
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
SET @ScanSourceID = (SELECT ScanSourceID FROM PowerSTIG.ScanSource WHERE ScanSource = @ScanSource)
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
-- ----------------------------------------
-- Find most recent scan
-- ----------------------------------------
--
	DROP TABLE IF EXISTS #RecentScan
--
	SELECT * INTO #RecentScan FROM 
         (
         SELECT  M.*, ROW_NUMBER() OVER (PARTITION BY TargetComputerID,ComplianceTypeID,ScanSourceID ORDER BY LastComplianceCheck DESC) RN
         FROM    PowerSTIG.ComplianceSourceMap M
         ) T
		WHERE
			T.RN = 1
-- ----------------------------------------
-- Return results
-- ----------------------------------------
--
	SELECT 
		R.InDesiredState
		,F.VulnerabilityNum AS RuleID
		,F.Severity
		,F.RuleTitle
		,F.CheckContent AS CheckDescription
		,L.LastComplianceCheck
	FROM
		PowerSTIG.FindingRepo R
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
				R.ScanID IN (select scanid from #RecentScan)
			AND
				R.TargetComputerID = @TargetComputerID
			AND
				R.ComplianceTypeID = @ComplianceTypeID
			AND
				S.ScanSourceID = @ScanSourceID
	GROUP BY				
		R.InDesiredState
		,F.VulnerabilityNum
		,F.Severity
		,F.RuleTitle
		,F.CheckContent
		,L.LastComplianceCheck
	ORDER BY
		F.VulnerabilityNum
-- ----------------------------------------
-- Cleanup
-- ----------------------------------------
	DROP TABLE IF EXISTS #RecentScan
GO
-- ==================================================================
-- PowerStig.sproc_GetStigTextByTargetScanCompliance 
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetStigTextByTargetScanCompliance]
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
-- Examples:
-- EXEC [PowerSTIG].[sproc_GetStigTextByTargetScanCompliance] @TargetComputerID = 1,@ComplianceTypeID =5
-- ===============================================================================================
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
		,S.VulnerabilityNum AS RuleID
		,S.Severity
		,S.RuleTitle AS Title
		,S.CheckContent AS CheckDescription
		,L.LastComplianceCheck
	FROM
		PowerSTIG.FindingRepo R
			JOIN
				PowerSTIG.CheckListAttributes S
			ON
				R.CheckListAttributeID = S.CheckListAttributeID
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