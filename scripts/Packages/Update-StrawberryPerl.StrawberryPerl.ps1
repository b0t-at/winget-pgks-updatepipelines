$latestVersionName = gh release view --repo $WebsiteURL --json name -q ".name"
$latestVersion = $latestVersionName -replace '.*?(\d+\.\d+\.\d+(.\d+)).*', '$1'
$assets = gh release view --repo $WebsiteURL --json assets -q ".assets[] .url"
$latestVersionUrl = $assets | Where-Object { $_ -like "*.msi" }

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
  }