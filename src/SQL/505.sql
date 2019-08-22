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
SET @UpdateVersion = 505
SET @VersionNotes = 'IIS Server/Site support'
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
-- ==================================================================
-- Cleanup from last release
-- ==================================================================
DROP TABLE IF EXISTS dbo.C2DE41B069764ED3A132E421721BCB4A
GO
-- ==================================================================
-- Add IISsiteName to FindingImport
-- ==================================================================
IF NOT EXISTS (
		SELECT [name] FROM sys.columns 
			WHERE  object_id = OBJECT_ID(N'[PowerSTIG].[FindingImport]') 
				AND [name] = 'IISsiteName')
        BEGIN
            ALTER TABLE PowerSTIG.FindingImport ADD IISsiteName varchar(512) NULL
        END
GO
-- ==================================================================
-- Alter sproc_InsertFindingImport, adding support for IISsiteName
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_InsertFindingImport]
				@PScomputerName varchar(255)
				,@VulnID varchar(25) 
				,@StigType varchar(256) 
				,@DesiredState varchar(25)
				,@ScanDate datetime
				,@GUID UNIQUEIDENTIFIER
				,@ScanSource varchar(25)
				,@ScanVersion varchar(8)
				,@IISsiteName varchar(512)=NULL
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
-- 08212019 - Kevin Barlett, Microsoft - IIS site support
--Use example:
--EXEC PowerSTIG.sproc_InsertFindingImport 'SERVER2012','V-26529','OracleJRE','True','09/17/2018 14:32:42','5B1DD2AD-025A-4264-AD0C-E11107F88004','SCAP','1.03'
--EXEC PowerSTIG.sproc_InsertFindingImport 'SERVER2012','V-26529','DotNetFramework','True','09/17/2018 14:32:42','5B1DD2AD-025A-4264-AD0C-E11107F88004','POWERSTIG','4.31'
-- Use example for IIS:
--EXEC PowerSTIG.sproc_InsertFindingImport 'SERVER2012R2','V-76839','IISSite','True','08/17/2019 14:32:42','7D475228-B28B-4B91-95DF-E6B70BEDE9C6','POWERSTIG','1.7','ThisIsMySiteThereAreManyLikeItButThisOneIsMine'
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
		ScanVersion,
		IISsiteName
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
		@ScanVersion,
		@IISsiteName
		)
END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
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
DECLARE @VulnID varchar(25)
DECLARE @StigType varchar(256)
DECLARE @SiteID INT
DECLARE @SiteName varchar(512)
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
SET @StepName = 'Retrieve StigType'
--------------------------------------------------------
	SET @StigType = (SELECT DISTINCT StigType FROM PowerSTIG.FindingImport WHERE [GUID] = @GUID)

------------------------------------------------
-- Here we go.  Does the GUID have sub-vulnerabilities (e.g. V-1234.a or V-1234.b)
------------------------------------------------
	IF EXISTS
		(SELECT VulnID FROM PowerSTIG.FindingImport WHERE VulnID LIKE '%.%' AND [GUID] = @GUID)
			BEGIN

				DROP TABLE IF EXISTS #__VulnScrubA
				--
				CREATE TABLE #__VulnScrubA 
						(
						TargetComputer varchar(255),
						VulnID varchar(25),
						StigType varchar(256),
						DesiredState varchar(25),
						ScanDate datetime,
						[GUID] char(36),
						ScanSource varchar(25),
						ImportDate datetime,
						ScanVersion varchar(8),
						IISsiteName varchar(512),
						ScrubbedVuln varchar(25),
						isCompliant BIT,
						isProcessed BIT
						)
				--
				INSERT INTO
					#__VulnScrubA
						(
						TargetComputer,
						VulnID,
						StigType,
						DesiredState,
						ScanDate,
						[GUID],
						ScanSource,
						ImportDate,
						ScanVersion,
						IISsiteName,
						ScrubbedVuln,
						isCompliant,
						isProcessed
						)
				SELECT 
					TargetComputer,
					VulnID,
					StigType,
					DesiredState,
					ScanDate,
					[GUID],
					ScanSource,
					ImportDate,
					ScanVersion,
					IISsiteName,
					LEFT([Vulnid], CHARINDEX('.',[Vulnid])-1) AS ScrubbedVuln,
					0 AS isCompliant,
					0 AS isProcessed
				FROM
					PowerSTIG.FindingImport
				WHERE
					VulnID like '%.%'
				AND 
					[GUID] = @GUID

------------------------------------------------
-- Roll through the VulnIDs and apply "logic" to determine DesiredState.  There is definitely a better way to do this.
------------------------------------------------

WHILE EXISTS
		(SELECT DISTINCT TOP 1 ScrubbedVuln FROM #__VulnScrubA WHERE isProcessed = 0)
			BEGIN
				SET @VulnID = (SELECT DISTINCT TOP 1 ScrubbedVuln FROM #__VulnScrubA WHERE isProcessed = 0)

					IF (SELECT COUNT(VulnID) FROM #__VulnScrubA WHERE DesiredState = 'False' AND ScrubbedVuln = @VulnID) > 0
						BEGIN
							UPDATE
								#__VulnScrubA
							SET
								isCompliant = 0
							WHERE
								ScrubbedVuln = @VulnID
						END
					ELSE
						BEGIN
							UPDATE
								#__VulnScrubA
							SET
								isCompliant = 1
							WHERE
								ScrubbedVuln = @VulnID
						END
				--
				UPDATE
					#__VulnScrubA
				SET
					isProcessed = 1
				WHERE
					ScrubbedVuln  = @VulnID
		

------------------------------------------------
-- Put the scrubbed/whatever VulnID back into FindingImport for processing
------------------------------------------------

		INSERT INTO PowerSTIG.FindingImport
					(TargetComputer
					,VulnID
					,StigType
					,DesiredState
					,ScanDate
					,[GUID]
					,ScanSource
					,ImportDate
					,ScanVersion
					,IISsiteName)

		SELECT 
			TargetComputer
			,ScrubbedVuln
			,StigType
			,DesiredState
			,ScanDate
			,[GUID]
			,ScanSource
			,ImportDate
			,ScanVersion
			,IISsiteName
		FROM    (SELECT 
					TargetComputer
					,ScrubbedVuln
					,StigType
					,CASE 
						WHEN isCompliant = 0 THEN 'False'
						WHEN isCompliant = 1 THEN 'True'
						END AS DesiredState
					,ScanDate
					,[GUID]
					,ScanSource
					,ImportDate
					,ScanVersion
					,IISsiteName
					,ROW_NUMBER() OVER (PARTITION BY ScrubbedVuln ORDER BY ScanDate) AS RowNumber
				 FROM  
					#__VulnScrubA) AS a
		WHERE  
			a.RowNumber = 1
	END
END
--------------------------------------------------------
-- Retrieve ScanID
--------------------------------------------------------
SET @ScanID = (SELECT ScanID FROM PowerSTIG.Scans WHERE [ScanGUID] = @GUID AND isProcessed = 0)
--
--------------------------------------------------------
-- Late breaking need to include IIS sites which do not fit the model for most of the other roles.
-- The IIS items below are a bit of a hack.
--------------------------------------------------------
IF @StigType = 'IISsite'
	BEGIN
--------------------------------------------------------
SET @StepName = 'Hydrate IISsites'
--------------------------------------------------------
		BEGIN TRY		
			INSERT INTO
					PowerSTIG.IISsites
						(
						SiteName
						)
				SELECT
						IISsiteName
				FROM
						PowerSTIG.FindingImport
				WHERE 
						IISsiteName NOT IN
					(
						SELECT
							SiteName
						FROM
							PowerSTIG.IISsites
					)
				AND
					[GUID] = @GUID
			--
			-- Retrieve SiteID and associate a scan to a site.  Such a hack.
			--
			SET @SiteName = (SELECT IISsiteName FROM PowerSTIG.FindingImport WHERE [GUID] = @GUID)
				SET @SiteID = (SELECT SiteID FROM PowerSTIG.IISsites WHERE SiteName = @SiteName)
			--
			-- Associate SiteID to a ScanID
			--
				INSERT INTO PowerSTIG.IISsitesScans
				
					(SiteID,ScanID)
				VALUES
					(@SiteID,@ScanID)

				--
				-- Do Logging
				--
				SET @StepMessage = 'Processing IISsite for: '+@GUID
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
			SET @StepMessage = 'Error inserting IISsites for '+@GUID+'.  Captured error info: '+@ErrorMessage+'.'
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
----------------------------------------------------------
--SET @StepName = 'Hydrate IISsitesScans'
----------------------------------------------------------
--	BEGIN TRY
--		IF @StigType = 'IISsite'
--			BEGIN
--				INSERT INTO PowerSTIG.IISsitesScans 
--						(
--						SiteID,
--						ScanID
--						)
--				SELECT
--					SiteID,
--					@ScanID AS ScanID
--				FROM
--					PowerSTIG.IISsites
--				WHERE
					
--END
--				--
--				-- Do Logging
--				--
--				SET @StepMessage = 'Processing IISsite for: '+@GUID
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
--			SET @StepMessage = 'Error inserting IISsites for '+@GUID+'.  Captured error info: '+@ErrorMessage+'.'
--			SET @StepAction = 'ERROR'
--			PRINT @StepMessage
--					--
--			EXEC PowerSTIG.sproc_InsertScanLog
--				@LogEntryTitle = @StepName
--			   ,@LogMessage = @StepMessage
--			   ,@ActionTaken = @StepAction
--			RETURN
--	END CATCH
------------------------------------------------
-- Retrieve CheckListInfoID
------------------------------------------------
		SET @OSid = (SELECT OSid FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = (SELECT DISTINCT TargetComputer FROM PowerSTIG.FindingImport WHERE [GUID] = @GUID))
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
	DROP TABLE IF EXISTS #__VulnScrubA
GO
-- ==================================================================
-- Create table PowerSTIG.IISsites
-- ==================================================================
DROP TABLE IF EXISTS PowerSTIG.IISsites
--
    CREATE TABLE PowerSTIG.IISsites (
        SiteID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SiteName varchar(512) NOT NULL)
GO
-- ==================================================================
-- Create table PowerSTIG.IISsitesScans
-- ==================================================================
DROP TABLE IF EXISTS PowerSTIG.IISsitesScans
--
    CREATE TABLE PowerSTIG.IISsitesScans (
        SiteScanID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SiteID INT NOT NULL,
        ScanID INT NOT NULL)
GO
-- ==================================================================
-- 
-- ==================================================================

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