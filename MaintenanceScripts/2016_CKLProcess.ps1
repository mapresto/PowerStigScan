#Path must be to base path for 2016 CKL with no changes
param(
    [String]$2016SourceCKLPath,
    [String]$RepoPath
)

[xml]$msCKL = Get-Content -Path (Join-Path -Path $2016SourceCKLPath -ChildPath "2016WindowsServerEmpty.ckl")
$msCKL.PreserveWhitespace = $true
[xml]$dcCKL = Get-Content -Path (Join-Path -Path $2016SourceCKLPath -ChildPath "2016WindowsServerEmpty.ckl")
$dcCKL.PreserveWhitespace = $true

$x = 0
$NotApplicable = "Not_Applicable"

foreach($i in $ckl.CHECKLIST.STIGS.iSTIG.VULN)
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