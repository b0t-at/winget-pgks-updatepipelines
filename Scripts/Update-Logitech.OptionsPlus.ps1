. .\Scripts\common.ps1


# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = $WebsiteURL
#create directory downloads and change into it
$DownloadFileName = "logioptionsplus_installer.exe"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName
$file = Get-ChildItem -Path $DownloadFileName
$versionInfo = $file.VersionInfo.ProductVersion

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

return $latestVersion, $latestVersionUrl
