$latestVersionUrl = "https://bandisoft.app/bandizip/BANDIZIP-SETUP-STD-X64.EXE"
$latestVersion = Get-ProductVersionFromFile -WebsiteURL $latestVersionUrl  -VersionInfoProperty ProductVersion

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}