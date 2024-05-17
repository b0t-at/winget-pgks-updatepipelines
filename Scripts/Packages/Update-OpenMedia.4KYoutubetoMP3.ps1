. .\Scripts\common.ps1

$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]

$ProductName = ($PackageName -replace '4K', '').Trim().ToLower()

$versionPattern = "$($ProductName)_(\d+\.\d+\.\d+\.\d+)"
$URLFilter = "$($ProductName)_windows"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$FilteredLinks = $WebsiteLinks | Where-Object { $_.Id -match $URLFilter }

Write-Host "Filtered Links: $($FilteredLinks.href)"

$versions = $FilteredLinks.outerHTML | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }


$latestVersionUrl = $FilteredLinks | ForEach-Object { ($_.href -replace '\?.*', '') }

Write-Host "latestVersionUrl: $latestVersionUrl"

$64bitCheckURL = $($latestVersionUrl| Where-Object { $_ -match "_online.exe" }).replace("_online.exe", "_x64_online.exe")

Write-Host "Checking: $64bitCheckURL"

$latestVersion = Get-ProductVersionFromFile -VersionInfoProperty "ProductVersion" -WebsiteURL $64bitCheckURL

$latestVersionUrl =+ $64bitCheckURL

#$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1


return $latestVersion, $latestVersionUrl