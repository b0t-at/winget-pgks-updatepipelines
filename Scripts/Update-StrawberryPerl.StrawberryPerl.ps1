. .\Scripts\common.ps1

$latestVersionTag = gh release view --repo $WebsiteURL --json tagName -q ".tagName"
$latestVersionName = gh release view --repo $WebsiteURL --json name -q ".name"
$latestVersion = $latestVersionName -replace '.*?(\d+\.\d+\.\d+(.\d+)).*', '$1'
$assets = gh release view --repo $WebsiteURL --json assets -q ".assets[] .url"
$msiAsset = $assets | Where-Object { $_ -like "*.msi" }

return $latestVersion, $msiAsset