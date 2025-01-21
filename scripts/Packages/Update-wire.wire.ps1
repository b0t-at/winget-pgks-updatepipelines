$repo = "wireapp/wire-desktop"
# get releases from github with github cli
$releases = gh release list -R $repo --json name,isLatest,tagName --order desc | ConvertFrom-Json

# get latest release where tag starts with windows
$latestWindowsTag = $null
foreach($release in $releases) {
    if($release.tagName -like "windows*") {
        $latestWindowsTag = $release.tagName
        break
    }
}

$latestVersion = $latestWindowsTag.Split("/")[1]
$latestVersionUrl = "https://github.com/wireapp/wire-desktop/releases/download/windows%2F$latestVersion/Wire-Setup.exe"

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}