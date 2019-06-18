-- ===============================================================================================
-- ===============================================================================================
-- Purpose: Deployment script for PowerSTIG database stored procedures
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
SET @UpdateVersion = 501
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
GO
-- ===============================================================================================
-- ==================================================================
-- sproc_GetActiveServers
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetActiveServers] 
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
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	SELECT DISTINCT
		TargetComputer
	FROM
		PowerSTIG.ComplianceTargets T
	WHERE
		T.isActive = 1
GO

-- ==================================================================
-- sproc_GetConfigSetting
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetConfigSetting 
					@ConfigProperty varchar(255)
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
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
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
-- ==================================================================
-- sproc_AddTargetComputer
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_AddTargetComputer
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
-- ==================================================================
-- sproc_GetLastComplianceCheckByTarget
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTarget
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
-- ==================================================================
-- sproc_GetLastComplianceCheckByTargetAndRole
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole
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
-- ==================================================================
-- sproc_UpdateConfig
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_UpdateConfig
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
			--
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
-- ==================================================================
-- sproc_InsertConfig
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_InsertConfig
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
-- ==================================================================
-- sproc_GetScanQueue
-- ==================================================================
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
-- ==================================================================
-- sproc_DeleteTargetComputerAndData
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerStig.sproc_DeleteTargetComputerAndData
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
-- ==================================================================
-- sproc_InsertFindingImport
-- ==================================================================
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
--------------------------------------------------------
SET @StepName = 'Hydrate Finding'
--------------------------------------------------------
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.Finding(Finding)
		SELECT DISTINCT
			LTRIM(RTRIM(VulnID)) AS Finding
		FROM 
			PowerSTIG.FindingImport
		WHERE
			LTRIM(RTRIM(VulnID)) NOT IN (SELECT Finding FROM PowerSTIG.Finding)
				--
				SET @StepMessage = 'Insert new findings into Findings table'
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
			SET @StepMessage = 'Error inserting new findings (STIGs) into Finding table.  Captured error info: '+@ErrorMessage+'.'
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
-- sproc_GetScanLog
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_ImportSTIGxml
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetCountServers
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetComplianceStateByRole
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetTargetComplianceTypeLastCheck
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GenerateDates
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetAdminFunction 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetComplianceStats 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetStigTextByTargetScanCompliance 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetQueuedScans 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_InsertNewScan 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_UpdateTargetOS 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GenerateORGxml 
-- ==================================================================
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
		IF @ComplianceType IN ('DotNetFramework','Firefox','WindowsFirewall','IISServer','IISSite','Word2013','Excel2013','PowerPoint2013','Outlook2013','OracleJRE','InternetExplorer','WindowsDefender','SqlServer-2012-Database','SqlServer-2012-Instance','SqlServer-2016-Instance')
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
-- PowerStig.sproc_ImportOrgSettingsXML 
-- ==================================================================
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
-- PowerStig.sproc_AddOrgSetting 
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetComplianceTypes
-- ==================================================================
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
-- ==================================================================
-- PowerStig.sproc_GetOrgSettingsByRole 
-- ==================================================================
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
-- PURPOSE:
-- REVISIONS:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
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
-- ==================================================================
-- PowerStig.sproc_GetRSpages 
-- ==================================================================
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
-- PURPOSE:
--
-- REVISIONS:
--
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
--
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
-- ==================================================================
-- PowerStig.sproc_GetLogDates 
-- ==================================================================
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
-- PURPOSE:
-- REVISIONS:
-- 04222019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
--
-- ===============================================================================================
--
	SELECT DISTINCT 
		DATEADD(day, 0, DATEDIFF(day, 0, LogTS)) AS LogDate
	FROM 
		PowerSTIG.ScanLog
	ORDER BY
		LogDate DESC
GO
-- ==================================================================
-- PowerStig.sproc_GetDetailedScanResults 
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetDetailedScanResults
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
		,F.Finding AS RuleID
		,X.Severity
		,X.Title
		,X.RawString AS CheckDescription
		,L.LastComplianceCheck
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
				PowerSTIG.Finding F
				on
				F.FindingID = R.FindingID
			JOIN
				PowerSTIG.StigTextRepo X
				ON
				F.Finding = X.RuleID
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
		,F.Finding
		,X.Severity
		,X.Title
		,X.RawString
		,L.LastComplianceCheck
	ORDER BY
		Finding
-- ----------------------------------------
-- Cleanup
-- ----------------------------------------
	DROP TABLE IF EXISTS #RecentScan
GO
-- ==================================================================
-- PowerStig.sproc_UpdateCKLtargetInfo 
-- ==================================================================
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
-- PURPOSE:
-- REVISIONS:
-- 05062019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
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
-- ==================================================================
-- PowerStig.sproc_GetCKLtargetInfo 
-- ==================================================================
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
-- PURPOSE:
-- REVISIONS:
-- 05062019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
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
-- ==================================================================
-- PowerStig.sproc_GetServersRoleCount
-- ==================================================================
CREATE OR ALTER PROCEDURE [PowerSTIG].[sproc_GetServersRoleCount] 
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
-- Returns target computers and the count of distinct compliance types (roles) associated with them.
-- REVISIONS:
-- 05212019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
-- EXEC PowerSTIG.sproc_GetServersRoleCount
-- ===============================================================================================
	DROP TABLE IF EXISTS #RecentScan
		--
	SELECT * INTO #RecentScan FROM 
         (
			         SELECT  M.*, ROW_NUMBER() OVER (PARTITION BY TargetComputerID,ComplianceTypeID ORDER BY LastComplianceCheck DESC) RN
         FROM    PowerSTIG.ComplianceSourceMap M
		          ) T
		WHERE
			T.RN = 1
--
-- Return results
--
	SELECT DISTINCT
		TargetComputer,
		COUNT(*) AS RoleCount
	FROM
		#RecentScan N
			JOIN
		PowerSTIG.ComplianceTargets T
			ON
		N.TargetComputerID = T.TargetComputerID
	GROUP BY
		TargetComputer
	ORDER BY
		TargetComputer
--
-- Cleanup
--
	DROP TABLE IF EXISTS #RecentScan
GO
-- ==================================================================
-- PowerStig.sproc_GetScanSource 
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetScanSource
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
-- Returns unique scan source types and their ID column (PK)
-- REVISIONS:
-- 05212019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
-- EXEC PowerSTIG.sproc_GetScanSource
-- ===============================================================================================
		SELECT
			ScanSource,
			ScanSourceID
		FROM
			PowerSTIG.ScanSource
GO
-- ==================================================================
-- PowerStig.sproc_GetTargetComputer 
-- ==================================================================
CREATE OR ALTER PROCEDURE PowerSTIG.sproc_GetTargetComputer
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
-- Returns unique target computers and their ID column (PK)
-- REVISIONS:
-- 05212019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLES:
-- EXEC PowerSTIG.sproc_GetTargetComputer
-- ===============================================================================================
		SELECT
			TargetComputer,
			TargetComputerID
		FROM
			PowerSTIG.ComplianceTargets
		WHERE
			isActive = 1
GO
-- ===============================================================================================
-- ===============================================================================================
-- ===============================================================================================
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