$versionPattern = "<h3>Betterbird (\d+\.\d+\.\d+-bb\d+)"

$URLFilter = "(.exe|.zip)"

$WebsiteUrl = "https://www.betterbird.eu/downloads/"
# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links
$WebsiteContent = $website.Content

$FilteredLinks = $WebsiteLinks | Where-Object { $_.Download -match $URLFilter }

$versions = $WebsiteContent | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }

$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1

$latestVersionUrl = $FilteredLinks | ForEach-Object { ($_.href -replace '\?.*', '') } | Where-Object { $_ -ne '' -and $_ -match $latestVersion -and $_ -notmatch "latest-build|Previous" } | ForEach-Object { $WebsiteURL + $_ }

# filter zips
$latestVersionUrl = $latestVersionUrl | Where-Object { $_ -match ".exe" }

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}