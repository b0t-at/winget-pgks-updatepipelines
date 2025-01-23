$latestVersionUrl = "https://dl.bandisoft.com/bandizip.std/BANDIZIP-SETUP-STD-X64.EXE"
$latestVersion = Get-ProductVersionFromFile -WebsiteURL $latestVersionUrl  -VersionInfoProperty ProductVersion

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}