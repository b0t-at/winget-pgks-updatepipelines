. .\Scripts\common.ps1

#### Main
$params = @{
    wingetPackage = ${Env:PackageName}
    WebsiteURL = ${Env:WebsiteURL}
}
if($Env:With) {
    $params.Add("With", $Env:With)
}
if($Env:Submit) {
    $params.Add("Submit", $true)
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


Update-WingetPackage @params

