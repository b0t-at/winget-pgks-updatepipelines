$wingetRepo = "Romanitho/Winget-AutoUpdate"

# get releases via gh cli
$releases = gh release list --repo $wingetRepo --json name,tagName,publishedAt,isLatest,isPrerelease | ConvertFrom-Json
$newestNightly = $releases | Where-Object { $_.isPrerelease -eq $true } | Sort-Object -Property publishedAt -Descending | Select-Object -First 1
$latestVersion = $newestNightly.tagName.TrimStart("v")

# get artifacts
$artifacts = gh release view $newestNightly.tagName --repo $wingetRepo --json assets | ConvertFrom-Json
$latestVersionUrl = $artifacts.assets | Where-Object { $_.name -like "*WAU.msi" } | Select-Object -ExpandProperty url

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
  }