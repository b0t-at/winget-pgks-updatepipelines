. .\Scripts\common.ps1

$PackageFilter = "mongocli"

Write-Host "Try to update $wingetPackage"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$content = $website.Content

# Find all strings that look like links and end with .msi
$links = $content | Select-String -Pattern 'https?://[^"]+' -AllMatches | % { $_.Matches } | % { $_.Value }
$msilinks = $links | Select-String -Pattern 'https?://[^\s]*\.msi' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }



$Packagelinks = $msilinks | Select-String -Pattern "https?://[^\s]*$PackageFilter[^\s]*\.msi" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }| Where-Object { $_ -notmatch "$PackageFilter-isolated|$PackageFilter-readonly" }
# Extract versions from the links
$versions = $Packagelinks | ForEach-Object { $_ -match '(\d+\.\d+\.\d+(-rc\d*|-beta\d*)?)' | Out-Null; $matches[1] }

# Exclude release candidates
$stableVersions = $versions | Where-Object { $_ -notmatch '(-rc|beta)' }

# Sort the versions and get the latest one
$latestVersion = $stableVersions | Sort-Object {[Version]$_} | Select-Object -Last 1
$latestVersionUrl = $Packagelinks | Where-Object { $_ -match $latestVersion }
Write-Host "Version found: $PackageFilter  $latestVersion. URL: $latestVersionUrl"


return $latestVersion, "$latestVersionUrl|x64"
