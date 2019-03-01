# PowerStigScan

### Release History
1.0.0.0 - Released February 8, 2019
1.0.0.2 - Released Feburary 25, 2019


## How It Works
PowerStigScan is used to automate STIG auditing and checklist generation through the use of the PowerSTIG module.
PowerStig uses DSC to configure an environment to be compliant with DISA STIGs using an automated process to convert 
the xccdf to a parsable xml file that is consumed by the module to generate the composite DSC resources.

PowerStigScan uses that engine with the declarative nature of DSC to test your environment against the compiled MOFs.
This module is made to be used with the companion Database, whose build script is in the SQL folder. The database
holds historical findings that can be used to compile the DISA CKL (Checklist) files that are consumable by
the DISA STIGViewer tool.

## How to Install

### Database Install
Minimum Requirement - SQL Server Express 2016

Using the PowerSTIG_DBobjectDeploy_#.sql script in the ..\SQL folder, modify the following lines:

- :setvar MAIL_PROFILE        "sas"
- :setvar CMS_SERVER			"STIG2016"
- :setvar CMS_DATABASE		"PowerSTIG"
- :setvar CKL_OUTPUT			"C:\Temp\PowerStig\CKL\"
- :setvar CKL_ARCHIVE			"C:\Temp\PowerStig\CKL\Archive\"
- :setvar CREATE_JOB			"Y"

The Server and Database should be the database location that you intend to install the database into. The MAIL_PROFILE is used to email reports from the database. CREATE_JOB will create a SQL agent job that can be used to automate scans on a
predetermined basis. The CKL_OUTPUT and CKL_ARCHIVE are used during the batch scanning function and are paths relative to the 
server or computer that is scanning (i.e. if there is a SQL01 and MS01, the database is on SQL01 and you are scanning from 
MS01, the path C:\TEMP will be determined by the scanning server, in this case C:\TEMP on MS01).

### Module Install
Using your preferred method to install this module you still need to configure a few settings to get started. First, using 
Get-PowerStigConfig, you can view the settings that are located in the config.ini that is located in the .\common directory.
These settings allow for simple and repeatable results in your environment. The primary settings to be concerned with will
be the SQL server and database that you will be connecting to. You can use Set-PowerStigConfig to modify these settings.

### Adding Target Computers
Computer objects must exist in the SQL Database prior to importing findings, which currently occurs at the end of the
Invoke-PowerStigScan and Invoke-PowerStigBatch cmdlets. You can use the Add-PowerStigComputer to populate the table with your
preferred method of bulk import. This will also declare the roles that are to be scanned against for each server during the 
Invoke-PowerStigBatch cmdlet.

## Known Issues
IIS, JRE, and SQL scans are not complete. We need to determine the information dynamically as storing static information will
be too burdensome for most administrators.


## ChangeLog
Added support for PowerSTIG 2.4
Fixed bugs related to Firefox install directory
Fixed bug related to computer names with hyphens
Updated Config functions for current Configuration Sets

