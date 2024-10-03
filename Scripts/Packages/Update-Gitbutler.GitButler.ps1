. .\scripts\common.ps1


# Follow redirect of https://app.gitbutler.com/downloads/release/windows/x86_64/msi
$website = $WebsiteURL
$absolutURL=[System.Net.HttpWebRequest]::Create($website).GetResponse().ResponseUri.AbsoluteUri

# regex to check if variable absolutURL is valid URL
$regex = "^(http|https)://([\w-]+.)+[\w-]+(/[\w- ./?%&=])?$"
if ($absolutURL -match $regex) {
    $latestVersionUrl = $absolutURL
    Write-Host "URL is valid"
}
else {
    Write-Host "URL is not valid"
    exit 1
}


# get full name of file from link
$fileName = $latestVersionUrl.Split("/")[-1]

# Get Version via Regex. The version is the part betweet "GitButler_" and "_x64"
$latestVersion = $fileName -replace ".*GitButler_(.*)_(x64|x86).*", '$1'

return $latestVersion, $latestVersionUrl
