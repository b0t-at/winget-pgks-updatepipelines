. .\Scripts\common.ps1

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
if($Env:Submit) {
    $params.Add("Submit", (ConvertTo-Bool -input $Env:Submit))
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

