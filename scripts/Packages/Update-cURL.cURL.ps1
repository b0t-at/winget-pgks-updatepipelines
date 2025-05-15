
$WebsiteURL = "https://curl.se/windows/"

$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]

$ProductName = ($PackageName).Trim().ToLower()

$versionPattern = "$($ProductName)-(\d+\.\d+\.\d+)_(\d+)-win"
$URLFilter = "curl-(\d+\.\d+\.\d+)_(\d+)-win.*-mingw.zip$"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$FilteredLinks = $WebsiteLinks | Where-Object { $_.href -match $URLFilter }

$versions = $FilteredLinks.href | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1
$builds = $FilteredLinks.href | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[2].Value }
$latestBuild = $builds | Sort-Object -Descending -Unique | Select-Object -First 1

$FullVersion = $latestVersion+"."+$latestBuild

$latestVersionUrls = $FilteredLinks | ForEach-Object { ($WebsiteURL+$_.href ) } | Select-Object -unique

# Check if the URLs are valid
$validUrls = $latestVersionUrls | Where-Object {
    $result = $null
    [System.Uri]::TryCreate($_, [System.UriKind]::Absolute, [ref]$result)
}

return [PSCustomObject]@{
    Version = $FullVersion
    URLs = $validUrls
}