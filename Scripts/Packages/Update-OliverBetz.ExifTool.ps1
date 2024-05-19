. .\Scripts\common.ps1

$PackageParts = $wingetPackage.Split('.')
$PackageName = $PackageParts[1]

$ProductName = ($PackageName).Trim().ToLower()

$versionPattern = "$($ProductName)_install_(\d+\.\d+)_(\d+)"
$URLFilter = "$($ProductName)_install_(\d+\.\d+)_(\d+)"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$FilteredLinks = $WebsiteLinks | Where-Object { $_.href -match $URLFilter }

$versions = $FilteredLinks.href | Select-String -Pattern $versionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
$latestVersion = $versions | Sort-Object -Descending -Unique | Select-Object -First 1

# extract website domain from the url
$parsedUri = New-Object System.Uri($WebsiteURL)
$baseUrl = $parsedUri.Scheme + "://" + $parsedUri.Host
$latestVersionUrls = $FilteredLinks | ForEach-Object { ($baseUrl+$_.href ) } | Select-Object -unique

# Check if the URLs are valid
$validUrls = $latestVersionUrls | Where-Object {
    $result = $null
    [System.Uri]::TryCreate($_, [System.UriKind]::Absolute, [ref]$result)
}

return $latestVersion, $validUrls