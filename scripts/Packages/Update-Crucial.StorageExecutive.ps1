$latestVersionUrl = $WebsiteURL

$versionInfo = Get-ProductVersionFromFile -WebsiteURL $WebsiteURL -VersionInfoProperty "ProductVersion"

return [PSCustomObject]@{
    Version = $versionInfo
    URLs = "$latestVersionUrl|x64"
}