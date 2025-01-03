$WebsiteURL = "https://www.ghisler.com/download.htm"
$website = Invoke-WebRequest -Uri $WebsiteURL

# parse version from text "	Download version 11.50 of Total Commander" via regex capture group
($website.Content -replace '\s+', ' ') -match '.*Download version (\d+\.\d+) of Total Commander.*'
$latestVersion = $matches[1]

$latestVersionUrls = $website.Links.href | Where-Object { $_ -like "*x64.exe" -or $_ -like "*x32.exe" }

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrls
}