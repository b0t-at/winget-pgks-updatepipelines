. .\Scripts\common.ps1

# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = $WebsiteURL
#create directory downloads and change into it
$DownloadFileName = "latest-win.exe"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName
$file = Get-ChildItem -Path $DownloadFileName
$versionInfo = $file.VersionInfo.ProductVersion

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

Write-Host "Found latest version: $versionInfo"
$latestversion = $versionInfo
# extract major and minor version e.g. 5.9 from 5.9.10
$majorMinorVersion = $versionInfo -replace '\.\d+$'
$fullDownloadURL = "https://5145542.fs1.hubspotusercontent-na1.net/hubfs/5145542/Knowledge%20Base/LD%20Software%20Downloads/$majorMinorVersion/LoupedeckInstaller_" + $versionInfo + ".exe"

Write-Host "Full download URL: $fullDownloadURL"

# check if full download URL is valid
$fullDownloadURLResponse = Invoke-WebRequest -Uri $fullDownloadURL -UseBasicParsing -Method Head
if ($fullDownloadURLResponse.StatusCode -ne 200) {
    Write-Host "Full download URL is not valid"
    exit 1
}

return $latestVersion, $fullDownloadURL
