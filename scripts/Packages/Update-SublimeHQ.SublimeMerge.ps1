. .\scripts\common.ps1

$WebsiteURL = "https://www.sublimemerge.com/download"
$website = Invoke-WebRequest -Uri $WebsiteURL

# Load the HTML content into an XML document
$WebsiteContent = $website.Content

# Define the regex pattern for build numbers (assuming they are sequences of digits)
$regexPattern = "\bBuild\s+(\d+)\b"
# Use Select-String to find all matches
$matchesResult = Select-String -InputObject $WebsiteContent -Pattern $regexPattern -AllMatches
# Extract and display the build numbers
$buildNumbers = $matchesResult.Matches | ForEach-Object { $_.Groups[1].Value }
$latestVersion = $buildNumbers | Sort-Object -Descending | Select-Object -First 1

$downLoadLinkExe = "https://download.sublimetext.com/sublime_merge_build_${latestVersion}_x64_setup.exe"
$downloadLinkZip = "https://download.sublimetext.com/sublime_merge_build_${latestVersion}_x64.zip"

return $latestVersion, @($downLoadLinkExe,$downloadLinkZip)
