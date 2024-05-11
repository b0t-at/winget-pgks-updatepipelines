. .\Scripts\common.ps1

#### Main
$params = @{
    wingetPackage = ${Env:PackageName}
    WebsiteURL = ${Env:WebsiteURL}
}
if($Env:With) {
    $params.Add("With", $Env:With)
}

Update-WingetPackage @params

