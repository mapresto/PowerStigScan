USE [PowerStig]
GO
/****** Object:  StoredProcedure [PowerSTIG].[sproc_GetTargetComplianceTypeLastCheck]    Script Date: 3/27/2019 6:38:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE [PowerSTIG].[sproc_GetTargetComplianceTypeLastCheck]
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

USE [PowerStig]
GO
/****** Object:  StoredProcedure [PowerSTIG].[sproc_GetStigTextByTargetScanCompliance]    Script Date: 3/27/2019 6:42:14 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER     PROCEDURE [PowerSTIG].[sproc_GetStigTextByTargetScanCompliance]
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
		,S.StigID
		,S.Severity
		,S.Title
		,S.CheckDescription
		,S.FixText
		,L.LastComplianceCheck
	FROM
			PowerSTIG.FindingRepo R
				INNER JOIN PowerSTIG.Finding F
					ON R.FindingID = F.FindingID
						INNER JOIN PowerSTIG.StigText S
							ON F.Finding = S.StigID
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
