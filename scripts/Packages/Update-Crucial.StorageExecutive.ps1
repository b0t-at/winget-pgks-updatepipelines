

$latestVersionUrl = $WebsiteURL

$versionInfo = Get-ProductVersionFromFile -WebsiteURL $WebsiteURL -VersionInfoProperty "ProductVersion"

return "$latestVersionUrl|x64", $versionInfo
