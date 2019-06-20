# PowerStigScan

### Release History
1.0.0.0 - Released February 8, 2019  
1.0.0.2 - Released Feburary 25, 2019  
1.1.0.0 - Released March 1, 2019  
2.0.0.0 - Released June 17, 2019  
2.1.0.0 - Released End of July/Early July

## What's New!
## Support for PowerStig 3.2.0

### SCAP Integration
With 2.0.0.0 we have introduced integration with the DISA SCAP Compliance Checker (SCC) tool. This is not a requirement to
run but it will allow you to use SCAP as an authoritative source for rules that it does cover. SCC does not have a lot of
overlap with this module, mostly on the OS checklists, but it is seen as an authoritative source in many DoD organizations.
If, between SCAP and PowerStigScan, there is a conflict between the two sources, the SCAP result will take precedence and will
be annotated on the checklist.

### Database Requirement Changes
Similarly, for those that are unable to use a SQL database in their environment, the requirement for a database has been
lowered. You would still see many benefits in using a database such as reporting and archiving of results but now you can
have basic functionality for CKL generation regardless of a database being present.

### Organizational Settings Support
We now support custom org settings with PowerStigScan in a more consistent manner. First and foremost, you can store the org
settings in the database for dynamic creation when a scan is triggered. Also, you can store your Org Settings XMLs in the
.\PSOrgSettings\ path of your configured log path (default is C:\Temp\PowerStig).


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

- :setvar MAIL_PROFILE          "MailProfile"			    
- :setvar MAIL_RECIPIENTS	    "user@mail.mil"		        
- :setvar CMS_SERVER			"STIG"					                     
- :setvar CMS_DATABASE		    "PowerStigScan1234"			 
- :setvar CKL_OUTPUT			"C:\Temp\PowerStig\CKL\"
- :setvar CKL_ARCHIVE			"C:\Temp\PowerStig\CKL\Archive\"
- :setvar ORG_SETTING_XML       "C:\Program Files\WindowsPowerShell\Modules\PowerSTIG\3.1.0\StigData\Processed"
- :setvar CREATE_JOB			"Y"

The Server and Database should be the database location that you intend to install the database into. The MAIL_PROFILE is used to email reports from the database. CREATE_JOB will create a SQL agent job that can be used to automate scans on a
predetermined basis. The CKL_OUTPUT and CKL_ARCHIVE are used during the batch scanning function and are paths relative to the 
server or computer that is scanning (i.e. if there is a SQL01 and MS01, the database is on SQL01 and you are scanning from 
MS01, the path C:\TEMP will be determined by the scanning server, in this case C:\TEMP on MS01).

### Module Install
Using your preferred method to install this module you still need to configure a few settings to get started. First, using 
Get-PowerStigConfig, you can view the settings that are located in the config.ini that is located in the .\common directory 
of the module.These settings allow for simple and repeatable results in your environment. The primary settings to be 
concerned with will be the SQL server and database that you will be connecting to. You can use Set-PowerStigConfig to modify 
these settings.

### Adding Target Computers
In order to use the SQL Batch functionality, the target servers must exist in the SQL database prior to attempting to running Invoke-PowerStigScan with the -SqlBatch switch. You can add servers to the database with the Add-PowerStigComputer cmdlet with the -ServerName parameter.

## Supported STIGs

### PowerStig and SCAP comparisons
#### (Can run in PowerStig only or PowerStig + SCAP modes)
Windows Server 2016 Member Server - 1.7  
Windows Server 2016 Domain Controller -1.7  
Windows Server 2012R2 Member Server - 2.15  
Windows Server 2012R2 Domain Controller - 2.16  
Windows 10 Client - 1.16  
Internet Explorer 11 - 1.16  
Windows Firewall - 1.7  
Windows Defender - 1.4
Mozilla Firefox - 4.25   

### PowerStig Only
Excel 2013 - 1.7  
PowerPoint 2013 - 1.6  
Word 2013 - 1.6  
Outlook 2013 - 1.13  
Windows Server 2012R2 DNS Server - 1.11    

### SCAP Only (Versions listed are for manual checklists)
Adobe Acrobat Reader DC Classic - 1.4  
Adobe Acrobat Reader DC Continuous - 1.5  
Google Chrome - 1.15  
.Net Framework - 1.7  

## Known Issues
IIS, JRE, and SQL scans are not complete. We need to determine the information dynamically as storing static information will
be too burdensome for most administrators.