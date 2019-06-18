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
SET NOCOUNT ON
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @UpdateVersion smallint
DECLARE @CurrentVersion smallint
SET @UpdateVersion = 499
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
-- 
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
-- ===============================================================================================
-- Create schema
-- ===============================================================================================
--
PRINT 'Begin create schema'
--
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'PowerSTIG')
	EXEC('CREATE SCHEMA [PowerSTIG] AUTHORIZATION [dbo]');
--
PRINT 'End create schema'
GO
-- ===============================================================================================
-- Create logging and versioning tables
-- ===============================================================================================
IF OBJECT_ID('PowerSTIG.DBversion') IS NULL
    --
    CREATE TABLE PowerSTIG.DBversion (
				VersionID smallint IDENTITY(1,1) NOT NULL PRIMARY KEY,
				UpdateVersion smallint NOT NULL DEFAULT(0),
				VersionTS datetime NOT NULL DEFAULT(GETDATE()),
				isActive INT NOT NULL,
                VersionNotes varchar(MAX) NULL)
--
 IF OBJECT_ID('PowerSTIG.ScanLog') IS NULL
--
	CREATE TABLE PowerSTIG.ScanLog (
				LogTS datetime NOT NULL DEFAULT(GETDATE()),
				LogEntryTitle varchar(128) NULL,
				LogMessage varchar(2000) NULL,
				ActionTaken varchar(25) NULL CONSTRAINT check_ActionTaken CHECK (ActionTaken IN ('INSERT','UPDATE','DELETE','DEPLOY','ERROR','START','FINISH')),
				LoggedUser varchar(50) NULL DEFAULT(SUSER_NAME()))
	--
GO
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_InsertScanLog
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
--SET @CurrentVersion = (SELECT TOP 1 CurrentVersion FROM __PowerStigDBdeployVersion)
			SET @StepMessage = 'Update version ['+CAST(@UpdateVersion as varchar(5))+'] successfully applied. This is an informational message only.'
			SET @StepAction = 'DEPLOY'
			--PRINT @StepMessage
					--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
			   ,@LogMessage = @StepMessage
			   ,@ActionTaken = @StepAction
--	
            INSERT INTO
				PowerSTIG.DBversion (UpdateVersion,VersionTS,isActive,VersionNotes)
			VALUES
				(@UpdateVersion,GETDATE(),1,NULL)
			
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
	DROP TABLE IF EXISTS __PowerStigDBdeployVersion
-- ===============================================================================================
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerStigScan database object deployment complete - '+CONVERT(VARCHAR,GETDATE(), 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
-- ===============================================================================================