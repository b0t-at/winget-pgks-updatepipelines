. .\Scripts\common.ps1

# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = $WebsiteURL
#create directory downloads and change into it
$DownloadFileName = "gusetup.exe"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName
$file = Get-ChildItem -Path $DownloadFileName
$versionInfo = $file.VersionInfo.ProductVersionRaw

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

return $versionInfo, $latestVersionUrl
