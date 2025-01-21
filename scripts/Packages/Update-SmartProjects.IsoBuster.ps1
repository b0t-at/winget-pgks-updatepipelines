$latestVersionUrl = $WebsiteURL -split " " | Select-Object -First 1

$versionInfo = Get-ProductVersionFromFile -WebsiteURL $latestVersionUrl -VersionInfoProperty "ProductVersion"

return [PSCustomObject]@{
    Version = $versionInfo
    URLs = $WebsiteURL
  }