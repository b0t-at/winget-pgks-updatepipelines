$PackageFilter = "mongodb-database-tools"

$Latest = Get-LatestMongoDBVersions -PackageFilter $PackageFilter -WebsiteURL $WebsiteURL

$latestVersion = $Latest.Version
$latestVersionUrl = $Latest.Url

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
  }