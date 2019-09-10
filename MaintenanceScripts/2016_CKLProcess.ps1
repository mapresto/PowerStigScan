#Path must be to base path for 2016 CKL with no changes
param(
    [String]$Source2016CKLPath,
    [String]$RepoPath
)

# Imports the CKL twice, once for the DC STIG and once for the MS STIG. PreserveWhiteSpace is necessary for formatting.
[xml]$msCKL = Get-Content -Path (Join-Path -Path $2016SourceCKLPath -ChildPath "2016WindowsServerEmpty.ckl")
$msCKL.PreserveWhitespace = $true
[xml]$dcCKL = Get-Content -Path (Join-Path -Path $2016SourceCKLPath -ChildPath "2016WindowsServerEmpty.ckl")
$dcCKL.PreserveWhitespace = $true

# Incremental value to help track between three documents in one script
$x = 0
# Hard code expected value for STIG when N/A is chosen.
$NotApplicable = "Not_Applicable"

foreach($i in $msCKL.CHECKLIST.STIGS.iSTIG.VULN)
{
    if($i.STIG_DATA[4].ATTRIBUTE_DATA -like "WN16-MS-*")
    {
        $dcCKL.CHECKLIST.STIGS.iSTIG.VULN[$x].STATUS = $NotApplicable
    }
    elseif($i.STIG_DATA[4].ATTRIBUTE_DATA -like "WN16-DC-*")
    {
        $msCKL.CHECKLIST.STIGS.iSTIG.VULN[$x].STATUS = $NotApplicable
    }
    $x++
}

$dcSavePath = Join-Path -Path $RepoPath -ChildPath "2016WindowsServer-DCEmpty.ckl"
$msSavePath = Join-Path -Path $RepoPath -ChildPath "2016WindowsServer-MSEmpty.ckl"

$dcCKL.Save($dcSavePath)
$msCKL.Save($msSavePath)