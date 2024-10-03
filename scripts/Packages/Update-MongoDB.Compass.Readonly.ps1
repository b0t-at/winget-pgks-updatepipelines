

$PackageFilter = "mongodb-compass-readonly"

$Latest = Get-LatestMongoDBVersions -PackageFilter $PackageFilter -WebsiteURL $WebsiteURL

$latestVersion = $Latest.Version
$latestVersionUrl = $Latest.Url

# Bring $latestVersion in correct format x.x.x.x
# Check if $latestVersion is in the x.x.x format
if ($latestVersion -match '^\d+\.\d+\.\d+$') {
    # Append .0 to $latestVersion
    $latestVersion = "$latestVersion.0"
}

return $latestVersion, $latestVersionUrl