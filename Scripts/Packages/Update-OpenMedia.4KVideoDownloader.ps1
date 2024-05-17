. .\Scripts\common.ps1

$versionPattern = "videodownloader_(\d+\.\d+\.\d+\.\d+)_windows_(x86|x64)"
$URLFilter = "videodownloader_windows_(x32|x64)_installer"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$FilteredLinks = $WebsiteLinks | Where-Object { $_.Id -match $URLFilter }

$versions = $FilteredLinks.outerHTML | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }

$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1

$latestVersionUrl = $FilteredLinks | ForEach-Object { ($_.href -replace '\?.*', '') }

return $latestVersion, $latestVersionUrl