. .\Scripts\common.ps1

#### Main

if (${Env:With}) {
    Update-WingetPackage -wingetPackage ${Env:PackageName} -With ${Env:With} -WebsiteURL ${Env:WebsiteURL}
}
else {
    Update-WingetPackage -wingetPackage ${Env:PackageName} -WebsiteURL ${Env:WebsiteURL}
}


