. .\Scripts\common.ps1

$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]

$ProductName = ($PackageName -replace '4K', '').Trim().ToLower()

$versionPattern = "$($ProductName)_(\d+\.\d+\.\d+\.\d+)_windows_(x86|x64)"
$URLFilter = "$($ProductName)_windows"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$FilteredLinks = $WebsiteLinks | Where-Object { $_.Id -match $URLFilter }

$versions = $FilteredLinks.outerHTML | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }

$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1

$latestVersionUrl = $FilteredLinks | ForEach-Object { ($_.href -replace '\?.*', '') }

$64bitCheckURL = $($latestVersionUrl| Where-Object { $_ -match "_online.exe" }).replace("_x64_online.exe", "_online.exe").replace("_online.exe", "_x64_online.exe") | Select-Object -unique

$latestVersionUrl = ($latestVersionUrl+$64bitCheckURL) | Select-Object -unique

return $latestVersion, $latestVersionUrl