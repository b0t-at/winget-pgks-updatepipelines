. .\Scripts\common.ps1

$PackageMapping = @{
    "MongoDB.Compass.Full" = "mongodb-compass"
    "MongoDB.Compass.Isolated" = "mongodb-compass-isolated"
    "MongoDB.Compass.Readonly" = "mongodb-compass-readonly"
}

Write-Host "Try to update MongoDB Tools"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$content = $website.Content

# Find all strings that look like links and end with .msi
$links = $content | Select-String -Pattern 'https?://[^"]+' -AllMatches | % { $_.Matches } | % { $_.Value }
$msilinks = $links | Select-String -Pattern 'https?://[^\s]*\.msi' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }

foreach ($wingetPackage in $PackageMapping.Keys){
$PackageFilter = $PackageMapping[$wingetPackage]
$Packagelinks = $msilinks | Select-String -Pattern "https?://[^\s]*$PackageFilter[^\s]*\.msi" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }| Where-Object { $_ -notmatch "$PackageFilter-isolated|$PackageFilter-readonly" }
# Extract versions from the links
$versions = $Packagelinks | ForEach-Object { $_ -match '(\d+\.\d+\.\d+(-rc\d*|-beta\d*)?)' | Out-Null; $matches[1] }

# Exclude release candidates
$stableVersions = $versions | Where-Object { $_ -notmatch '(-rc|beta)' }

# Sort the versions and get the latest one
$latestVersion = $stableVersions | Sort-Object {[Version]$_} | Select-Object -Last 1
$latestVersionUrl = $Packagelinks | Where-Object { $_ -match $latestVersion }
Write-Host "Version found: $PackageFilter $latestVersion. URL: $latestVersionUrl"

# Bring $latestVersion in correct format x.x.x.x
# Check if $latestVersion is in the x.x.x format
if ($latestVersion -match '^\d+\.\d+\.\d+$') {
    # Append .0 to $latestVersion
    $latestVersion = "$latestVersion.0"
}

return $latestVersion, $latestVersionUrl