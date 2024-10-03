. .\scripts\common.ps1

#### Main
$params = @{
    wingetPackage = ${Env:PackageName}
}
if($Env:WebsiteURL) {
    $params.Add("WebsiteURL", $Env:WebsiteURL)
}
if($Env:With) {
    $params.Add("With", $Env:With)
}
if($Env:Submit -eq $true) {
    $params.Add("Submit", $true)
}
else {
    $params.Add("Submit", $false)
}
if($Env:latestVersion) {
    $params.Add("latestVersion", $Env:latestVersion)
}
if($Env:latestVersionURL) {
    $params.Add("latestVersionURL", $Env:latestVersionURL)
}
if($Env:resolves) {
    $params.Add("resolves", $Env:resolves)
}
# make use of truthy evaluation to convert to clean bool
if($Env:TemplateUpgrade -eq $true) {
    $params.Add("IsTemplateUpdate", $true)
}
else {
    $params.Add("IsTemplateUpdate", $false)
}


Update-WingetPackage @params

