$websiteURL = "https://app.gitbutler.com/releases/release"
$releaseNotesURL = "https://github.com/gitbutlerapp/gitbutler/releases"

$website = Invoke-WebRequest -Uri $websiteURL -UseBasicParsing
$WebsiteContent = $website.Content
$LatestJSON = $WebsiteContent | ConvertFrom-Json

$latestVersionUrl = ($LatestJSON.platforms.'windows-x86_64'.url).Replace(".zip", "")
$releaseNotesJSON = $LatestJSON.notes

$latestVersion = $LatestJSON[0].Version

# Convert the extracted content to YAML format
$yamlContent = "ReleaseNotes: |-`n"
$lines = $releaseNotesJSON -split "`n"
foreach ($line in $lines) {
    $yamlContent += "  $line`n"
}

$releaseNotes = $yamlContent.trim() + "`nReleaseNotesUrl: $releaseNotesURL"

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
    ReleaseNotes = $releaseNotes
  }

### Old Version with HTML Parsing of Website for future reference

# # Follow redirect of https://app.gitbutler.com/downloads/release/windows/x86_64/msi
# $website = $WebsiteURL
# $absolutURL=[System.Net.HttpWebRequest]::Create($website).GetResponse().ResponseUri.AbsoluteUri

# # regex to check if variable absolutURL is valid URL
# $regex = "^(http|https)://([\w-]+.)+[\w-]+(/[\w- ./?%&=])?$"
# if ($absolutURL -match $regex) {
#     $latestVersionUrl = $absolutURL
#     Write-Host "URL is valid"
# }
# else {
#     Write-Host "URL is not valid"
#     exit 1
# }


# # get full name of file from link
# $fileName = $latestVersionUrl.Split("/")[-1]

# # Get Version via Regex. The version is the part betweet "GitButler_" and "_x64"
# $latestVersion = $fileName -replace ".*GitButler_(.*)_(x64|x86).*", '$1'

# return $latestVersion, $latestVersionUrl