param(
    [Parameter(Mandatory = $true)][string]$PackageId,
    [Parameter(Mandatory = $false)][string]$Version,
    [Parameter(Mandatory = $false)][bool]$Submit = $false,
    [Parameter(Mandatory = $false)][string]$resolves
)

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Parent $scriptPath
Import-Module "$scriptDirectory\..\modules\WingetMaintainerModule"


$gitToken = Test-GitHubToken
# get the version from the output
if ($Version -eq $null) {
    $Version = Get-LatestVersionInWinget -PackageId $PackageId
}
$prMessage = "Update Hash for package $PackageId version $Version"
Install-WingetCreate
.\wingetcreate.exe update $PackageId -r $Version ($Submit -eq $true ? "-s" : $null ) --prtitle $prMessage -t $gitToken