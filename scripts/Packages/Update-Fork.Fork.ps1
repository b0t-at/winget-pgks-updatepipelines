$websiteContent = Invoke-WebRequest -Uri $WebsiteURL
$latestVersionUrl = $websiteContent.Links | Where-Object {$_.tagName -eq "A" -and ($_.outerHTML.Contains('"downloadBtn2Win"') -or $_.outerHTML.Contains('"downloadBtn1Win"'))} | Select-Object -First 1 -ExpandProperty href
# extract version from link
$latestVersion = [regex]::Match($latestVersionUrl, '.*Fork-(.*).exe').Groups[1].Value

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
}