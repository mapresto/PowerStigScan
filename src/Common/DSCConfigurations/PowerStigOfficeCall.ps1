param(

    [Parameter(Mandatory=$true,Position=1)]
    [String]
    $ComputerName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Outlook2013', 'Excel2013', 'Word2013', 'PowerPoint2013')]
    [string]
    $OfficeApp,

    [Parameter(Mandatory=$false)]
    [String]
    $StigVersion

)

configuration PowerStigOfficeCall
{
    Import-DscResource -ModuleName PowerStig -ModuleVersion 2.3.2.0

    Node $ComputerName
    {
        if($OfficeApp -eq 'Outlook2013')
        {
            Office Outlook
            {
                OfficeApp       = $OfficeApp
                StigVersion     = $StigVersion
            } 
        }elseif($OfficeApp -eq 'Excel2013')
        {
            Office Excel
            {
                OfficeApp       = $OfficeApp
                StigVersion     = $StigVersion
            } 
        }elseif($OfficeApp -eq 'Word2013')
        {
            Office Word
            {
                OfficeApp       = $OfficeApp
                StigVersion     = $StigVersion
            } 
        }elseif($OfficeApp -eq 'PowerPoint2013')
        {
            Office PowerPoint
            {
                OfficeApp       = $OfficeApp
                StigVersion     = $StigVersion
            } 
        }
    }
}

PowerStigOfficeCall