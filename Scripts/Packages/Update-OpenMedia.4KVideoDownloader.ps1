. .\scripts\common.ps1

$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]

$ProductName = ($PackageName -replace '4K', '').Trim().ToLower()

$versionPattern = "$($ProductName)_(\d+\.\d+\.\d+\.\d+)_windows_(x86|x64)"
$URLFilter = "$($ProductName)_windows_(x32|x64)_installer"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links
$WebsiteContent = $website.Content

$FilteredLinks = $WebsiteLinks | Where-Object { $_.Id -match $URLFilter }

$BigVersion = $FilteredLinks | ForEach-Object { $_.href -replace '.*_(\d+\.\d+\.\d+).*', '$1' } | Sort-Object -Descending -Unique | Select-Object -First 1
$versionPattern = "($($BigVersion)\.\d+)"
$versions = $WebsiteContent | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }

$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1

$latestVersionUrl = $FilteredLinks | ForEach-Object { ($_.href -replace '\?.*', '') } | Where-Object { $_ -ne '' }

return $latestVersion, $latestVersionUrl