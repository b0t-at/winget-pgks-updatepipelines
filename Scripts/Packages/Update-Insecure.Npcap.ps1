. .\Scripts\common.ps1


$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]

$ProductName = ($PackageName).Trim().ToLower()

$versionPattern = "$($ProductName)-(\d+\.\d+(\.\d+)?).exe"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$FilteredLinks = $WebsiteLinks | Where-Object { $_.href -match $versionPattern }

$versions = $FilteredLinks.href | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1

$latestVersionUrl = $FilteredLinks | Where-Object { $_.href -match $latestVersion } | ForEach-Object { ($WebsiteURL+$_.href ) } | Select-Object -unique


return $latestVersion, $latestVersionUrl
