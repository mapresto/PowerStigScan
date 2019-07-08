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
SET @VersionNotes = 'New table GlobalScans | Alter sproc ProcessFindings to support GlobalScanGUIDs'
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
              (@UpdateVersion,GETDATE(),0,@VersionNotes)
-- ===============================================================================================
-- ===============================================================================================
--
-- Cleanup from last release
DROP TABLE IF EXISTS dbo.C2DE41B069764ED3A132E421721BCB4A
GO
-- ==================================================================
-- CREATE TABLE PowerSTIG.GlobalScans
-- ==================================================================
IF OBJECT_ID('PowerSTIG.GlobalScans') IS NULL
	CREATE TABLE PowerSTIG.GlobalScans (
		GlobalScanID INT IDENTITY(0,1) NOT NULL PRIMARY KEY,
		GlobalScanGUID CHAR(36) NOT NULL,
		GlobalScanDate datetime DEFAULT(GETDATE()) NOT NULL
		)
GO
-- ==================================================================
-- Initial seed of GlobalScans
-- ==================================================================
			SET IDENTITY_INSERT PowerSTIG.GlobalScans ON
			--
				DECLARE @SeedGUID char(36)
				SET @SeedGUID = (SELECT NEWID())
				INSERT INTO PowerSTIG.GlobalScans 
						(GlobalScanID,GlobalScanGUID,GlobalScanDate) 
				VALUES 
						(0,@SeedGUID,GETDATE()) 
			--
			SET IDENTITY_INSERT PowerSTIG.GlobalScans OFF
GO
-- ==================================================================
-- Add GlobalScanGUID to FindingImport table
-- ==================================================================
ALTER TABLE PowerSTIG.FindingImport ADD GlobalScanGUID char(36) NULL
GO
-- ==================================================================
-- Add GlobalScanGUID to FindingRepo table
-- ==================================================================
ALTER TABLE PowerSTIG.FindingRepo ADD GlobalScanID INT DEFAULT(0) NOT NULL
GO
-- ==================================================================
-- Add GlobalScanID FK to FindingRepo
-- ==================================================================
ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_GlobalScanID] FOREIGN KEY([GlobalScanID])
			REFERENCES [PowerSTIG].[GlobalScans] ([GlobalScanID])


GO
-- ==================================================================
-- sproc_ProcessFindings
-- ==================================================================
CREATE OR ALTER  PROCEDURE [PowerSTIG].[sproc_ProcessFindings] 
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
-- 07082019 - Kevin Barlett, Microsoft - Support for GlobalScanGUIDs to support specific CKL generation
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
SET @StepName = 'Retrieve new GlobalGUIDs'
--------------------------------------------------------
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.GlobalScans (GlobalScanGUID,GlobalScanDate)
		SELECT DISTINCT
			I.[GlobalScanGUID]
			,I.ScanDate
		FROM
			PowerSTIG.FindingImport I
		WHERE I.[GlobalScanGUID] NOT IN
			(SELECT GlobalScanGUID FROM PowerSTIG.GlobalScans WHERE GlobalScanGUID IS NOT NULL)

				SET @StepMessage = 'Insert GlobalScanGUIDs into GlobalScans'
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
			SET @StepMessage = 'Error inserting GlobalScanGUIDs into GlobalScans table.  Captured error info: '+@ErrorMessage+'.'
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
GO
-- =======================================================
-- Cleanup
-- =======================================================
	DROP TABLE IF EXISTS #NewComplianceTarget
	
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
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
	DROP TABLE IF EXISTS __PowerStigDBdeployVersion
-- ===============================================================================================
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerStigScan database object deployment complete - '+CONVERT(VARCHAR,GETDATE(), 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
-- ===============================================================================================