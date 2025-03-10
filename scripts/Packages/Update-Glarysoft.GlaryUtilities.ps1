$latestVersionUrl = $WebsiteURL
# download latest version from loupedeck.com and get version by filename
$versionInfo = Get-ProductVersionFromFile -WebsiteURL $WebsiteURL -VersionInfoProperty "ProductVersionRaw"

return [PSCustomObject]@{
    Version = $versionInfo
    URLs = $latestVersionUrl
  }
