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
SET @UpdateVersion = 502
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
IF (OBJECT_ID('PowerSTIG.PK_Scans_ScanID', 'PK') IS NULL)
		ALTER TABLE PowerSTIG.Scans ADD CONSTRAINT PK_Scans_ScanID PRIMARY KEY CLUSTERED (ScanID)
		--
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ScanID', 'F') IS NULL)
		ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD CONSTRAINT [FK_FindingRepo_ScanID] FOREIGN KEY([ScanID])
		REFERENCES [PowerSTIG].[Scans] ([ScanID])
		--
IF (OBJECT_ID('PowerSTIG.FK_Scans_ScanSourceID', 'F') IS NULL)
		ALTER TABLE [PowerSTIG].[Scans]  WITH NOCHECK ADD CONSTRAINT [FK_Scans_ScanSourceID] FOREIGN KEY([ScanSourceID])
		REFERENCES [PowerSTIG].[ScanSource] ([ScanSourceID])
        --
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ScanID', 'F') IS NULL)
		ALTER TABLE [PowerSTIG].[FindingRepo]  WITH NOCHECK ADD CONSTRAINT [FK_FindingRepo_ScanID] FOREIGN KEY([ScanID])
		REFERENCES [PowerSTIG].[Scans] ([ScanID])
		--
GO
--------------------------------------------------------
-- [PowerSTIG].[sproc_TrendTargetRoleSource]
--------------------------------------------------------
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_TrendTargetRoleSource]
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
-- PURPOSE:
-- 
-- REVISIONS:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
-- EXEC [PowerSTIG].[sproc_TrendTargetRoleSource] @TargetComputer = 'WIN10'
-- ===============================================================================================
--
DECLARE @TargetComputerID INT
--declare @TargetComputer varchar(255)
--set @TargetComputer = 'SQLtest006'
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
--

-- =======================================================
-- Find the most recent scan for each target + compliance type combination
-- =======================================================

	DROP TABLE IF EXISTS #RecentScan
--

SELECT * INTO #RecentScan FROM 
         (
         SELECT  
			M.*, ROW_NUMBER() OVER (PARTITION BY TargetComputerID,ComplianceTypeID,ScanSourceID ORDER BY LastComplianceCheck DESC) RN
         FROM
			PowerSTIG.ComplianceSourceMap M
		 WHERE
			M.TargetComputerID = @TargetComputerID
			
         ) T
		WHERE
			T.RN = 1

-- =======================================================
-- Return results
-- =======================================================
	SELECT
		ComplianceType,
		COUNT(R.inDesiredState) AS NumberOfCompliantFindings,
		O.ScanSource,
		CONVERT(varchar,S.ScanDate,101) AS ScanDate
		--S.ScanDate
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
			JOIN
				PowerSTIG.ScanSource O
			ON
				O.ScanSourceID = S.ScanSourceID

	WHERE
		R.InDesiredState = 1
		AND
		R.TargetComputerID = @TargetComputerID
		AND
		R.ScanID IN (SELECT ScanID FROM #RecentScan)
	GROUP BY
		T.ComplianceType,R.inDesiredState,O.ScanSource,ScanDate
GO
--------------------------------------------------------
-- CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetOrgSettingsByRole]
--------------------------------------------------------
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetOrgSettingsByRole]
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
-- PURPOSE:
-- REVISIONS:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
-- ===============================================================================================
--
DECLARE @ComplianceTypeID INT
--declare @ComplianceType varchar(256)
--set @ComplianceType = 'WindowsServer-MS'
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = @ComplianceType)
 SELECT
	T.ComplianceType,
	R.Finding AS RuleID,
	P.RawString AS FindingText,
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
		JOIN
			PowerSTIG.StigTextRepo P
		ON
			P.RuleID = F.Finding
WHERE
	T.ComplianceTypeID = @ComplianceTypeID
ORDER BY
	R.Finding
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
