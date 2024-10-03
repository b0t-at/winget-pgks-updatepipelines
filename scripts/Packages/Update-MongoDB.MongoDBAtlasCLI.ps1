. .\scripts\common.ps1

$PackageFilter = "mongodb-atlas-cli"

$Latest = Get-LatestMongoDBVersions -PackageFilter $PackageFilter -WebsiteURL $WebsiteURL

$latestVersion = $Latest.Version
$latestVersionUrl = $Latest.Url

return $latestVersion, "$latestVersionUrl|x64"