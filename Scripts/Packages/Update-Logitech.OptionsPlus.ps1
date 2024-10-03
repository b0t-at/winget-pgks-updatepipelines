. .\scripts\common.ps1

$latestVersionUrl = $WebsiteURL
# download latest version from loupedeck.com and get version by filename
$versionInfo = Get-ProductVersionFromFile -WebsiteURL $WebsiteURL -VersionInfoProperty "ProductVersion"

return $versionInfo, $latestVersionUrl
