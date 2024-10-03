. .\scripts\common.ps1

$latestVersionUrl = $WebsiteURL

# download latest version from loupedeck.com and get version by filename
$versionInfo = Get-ProductVersionFromFile -WebsiteURL $WebsiteURL -VersionInfoProperty "ProductVersion"


Write-Host "Found latest version: $versionInfo"
$latestversion = $versionInfo
# extract major and minor version e.g. 5.9 from 5.9.10
$majorMinorVersion = $versionInfo -replace '\.\d+\.\d+$'
$fullDownloadURL = "https://support.loupedeck.com/hubfs/Knowledge%20Base/LD%20Software%20Downloads/$majorMinorVersion/LoupedeckInstaller_" + $versionInfo + ".exe"
Write-Host "Full download URL: $fullDownloadURL"

# check if full download URL is valid
$fullDownloadURLResponse = Invoke-WebRequest -Uri $fullDownloadURL -UseBasicParsing -Method Head
if ($fullDownloadURLResponse.StatusCode -ne 200) {
    Write-Host "Full download URL is not valid"
    exit 1
}

return $latestVersion, $fullDownloadURL
