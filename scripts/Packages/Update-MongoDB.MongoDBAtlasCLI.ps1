$PackageFilter = "mongodb-atlas-cli"

$Latest = Get-LatestMongoDBVersions -PackageFilter $PackageFilter -WebsiteURL $WebsiteURL

$latestVersion = $Latest.Version
$latestVersionUrl = $Latest.Url

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = "$latestVersionUrl|x64"
  }