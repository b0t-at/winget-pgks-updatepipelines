. .\Scripts\common.ps1



# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteContent = $website.Content
$WebsiteLinks = $website.Links

$WebsiteversionPattern = "WinRAR (\d+\.\d+(\.\d+)?) is available"
$Websiteversion = $WebsiteContent | Select-String -Pattern $WebsiteversionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }

$UrlVersion = $Websiteversion -replace '\.', ''
$latestVersion = $Websiteversion
# Check if $latestVersion is in the x.x.x format
if ($latestVersion -notmatch '^\d+\.\d+\.\d+$') {
    # Append .0 to $latestVersion
    $latestVersion = "$latestVersion.0"
}

$URLFilter = "winrar-(x64|x32)-$UrlVersion"

$FilteredLinks = $WebsiteLinks | Where-Object { $_ -match $URLFilter }
$latestVersionUrl = $FilteredLinks | ForEach-Object { (($WebsiteURL -replace '/$', '') + $_.href) }

return $latestVersion, $latestVersionUrl
