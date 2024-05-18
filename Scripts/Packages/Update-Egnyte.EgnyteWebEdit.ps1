. .\Scripts\common.ps1

$latestVersionUrlTemplate = "https://egnyte-cdn.egnyte.com/webedit/win/en-us/{0}/EgnyteWebEdit_{0}_{1}.msi"

# download latest version from loupedeck.com and get version by filename
$MSIFileInformation = Get-MSIFileInformation -WebsiteURL $WebsiteURL

$FullVersion = $MSIFileInformation.ProductVersion

# Split the full version into two parts
$versionParts = $FullVersion.Split(".")

# The first three parts make up the version
$MajorVersion = [string]::Join(".", $versionParts[0..2]).TrimEnd('0')

# The last part is the second value
$MinorVersion = $versionParts[3]

$latestVersionUrl = $latestVersionUrlTemplate -f $MajorVersion, $MinorVersion

return $FullVersion, $latestVersionUrl
