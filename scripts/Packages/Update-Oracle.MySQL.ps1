$DownloadBaseDomain = "https://cdn.mysql.com//Downloads/MySQLInstaller/"
$websiteURL = "https://dev.mysql.com/downloads/windows/installer/"

# Download the webpage
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36 Edg/133.0.0.0"
$website = Invoke-WebRequest -Uri $WebsiteURL `
-WebSession $session `
-Headers @{
"authority"="dev.mysql.com"
  "method"="GET"
  "path"="/downloads/windows/installer/"
  "scheme"="https"
  "accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
  "accept-encoding"="gzip, deflate, br, zstd"
  "accept-language"="de,de-DE;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6"
  "cache-control"="max-age=0"
  "dnt"="1"
  "priority"="u=0, i"
  "sec-ch-ua"="`"Not(A:Brand`";v=`"99`", `"Microsoft Edge`";v=`"133`", `"Chromium`";v=`"133`""
  "sec-ch-ua-mobile"="?0"
  "sec-ch-ua-platform"="`"Windows`""
  "sec-fetch-dest"="document"
  "sec-fetch-mode"="navigate"
  "sec-fetch-site"="none"
  "sec-fetch-user"="?1"
  "upgrade-insecure-requests"="1"
}

# Extract the content of the webpage
$WebsiteLinks = $website.Links

$WebsiteversionPattern = "mysql-installer-community-(\d+\.\d+(\.\d+)?).0.msi"
$Websiteversion = $WebsiteLinks | Select-String -Pattern $WebsiteversionPattern -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -unique
$FileName = ($WebsiteLinks | Select-String -Pattern $WebsiteversionPattern -AllMatches | ForEach-Object { $_.Matches }).Value | Sort-Object -unique

$latestVersion = $Websiteversion

$latestVersionUrl = $DownloadBaseDomain+$FileName

$FileTest = Get-MSIFileInformation -WebsiteURL $latestVersionUrl

if ($FileTest.FileName -ne $FileName) {
    Write-Error "URL not working"
    exit 1
}

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
  }
