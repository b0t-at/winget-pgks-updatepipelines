$latestRelease = gh release list --repo bitwarden/clients --limit 100 --json isLatest,name,tagName,createdAt | ConvertFrom-Json  | Where-Object { $_.tagName -like "cli-*" } | Select-Object -First 1

$latestVersion = Remove-GHTagPrefixes $latestRelease.tagName.split('-')[1]

# get assets from release
$assets = (gh release view $latestRelease.tagName --repo bitwarden/clients --json assets | ConvertFrom-Json).assets | Where-Object {$_.url -like "*bw-windows-$latestVersion.zip"}
$latestVersionUrl = $assets.url

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}