. .\Scripts\common.ps1



# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$content = $website.Content

# Find all strings that look like links and end with .msi
$links = $content | Select-String -Pattern 'https?://[^"]+' -AllMatches | % { $_.Matches } | % { $_.Value }
$Packagelinks = $links | Select-String -Pattern 'https?://[^\s]*mongosh[^\s]*\.msi' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }


# Extract versions from the links
$versions = $Packagelinks | ForEach-Object { $_ -match '(\d+\.\d+\.\d+(-rc\d*|-beta\d*)?)' | Out-Null; $matches[1] }

# Exclude release candidates
$stableVersions = $versions | Where-Object { $_ -notmatch '(-rc|beta)' }

# Sort the versions and get the latest one
$latestVersion = $stableVersions | Sort-Object {[Version]$_} | Select-Object -Last 1
$latestVersionUrl = $Packagelinks | Where-Object { $_ -match $latestVersion }

return $latestVersion, $latestVersionUrl

