$latestVersion = Get-ProductVersionFromFile -WebsiteURL "https://dl.bandisoft.com/bandizip.std/BANDIZIP-SETUP-STD-X64.EXE" -VersionInfoProperty ProductVersion

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}