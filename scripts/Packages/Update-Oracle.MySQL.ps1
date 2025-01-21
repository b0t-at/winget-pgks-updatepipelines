$DownloadBaseDomain = "https://dev.mysql.com/get/Downloads/MySQLInstaller/"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

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