#$websiteContent = Invoke-WebRequest -Uri $WebsiteURL
#$latestVersionUrl = $websiteContent.Links | Where-Object {$_.tagName -eq "A" -and ($_.outerHTML.Contains('"downloadBtn2Win"') -or $_.outerHTML.Contains('"downloadBtn1Win"'))} | Select-Object -First 1 -ExpandProperty href
# extract version from link
#$latestVersion = [regex]::Match($latestVersionUrl, '.*Fork-(.*).exe').Groups[1].Value

$releasesURL = 'https://git-fork.com/update/win/RELEASES'
$versionRegex = "([A-Z,0-9]{0,128}) Fork-(\d\.\d{1,2}\.\d{1,2})(?:-full.nupkg \d.+)"

$releasesRaw = Invoke-WebRequest -Uri $releasesURL
$releasesDecoded = [System.Text.Encoding]::ASCII.GetString($releasesRaw.Content)
$releaseValues = ($releasesDecoded | select-string -pattern $versionRegex -AllMatches).Matches

$releaseFound = $false
# reverse releaseValues list
$releaseValues = $releaseValues | ForEach-Object { $_ } | Sort-Object -Property Index -Descending

foreach ($release in $releaseValues) {
    $latestVersion = $release.Groups[2].Value
    $latestVersionUrl = "https://cdn.fork.dev/win/Fork-" + $latestVersion + ".exe"
    try {
        $res = Invoke-WebRequest -Method Head -Uri $latestVersionUrl
    }
    catch {
        Write-Host "Failed to get $latestVersionUrl"
        continue
    }
    if ($res.StatusCode -eq 200) {
        $releaseFound = $true
        break
    }
}

if (-not $releaseFound) {
    throw "No release found"
}

return [PSCustomObject]@{
    Version = $latestVersion
    URLs    = $latestVersionUrl
}