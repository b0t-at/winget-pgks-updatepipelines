


# Currently not all versions have .exe installers
#Text response with entries of form "<SHA> Fork-<Version>-<FUll|Delta>.nupkg <SIZE>"
# Invoke-WebRequest -Uri "https://git-fork.com/update/win/RELEASES?id=Fork" -OutFile "RELEASES"
# $releases = Get-Content "RELEASES"
# $versionNumbers = $releases | ForEach-Object {
#     if ($_ -match 'Fork-(.*?)-') {
#         $Matches[1]
#     }
# }
# $versionNumbers = $versionNumbers | Sort-Object -Descending | Select-Object -Unique

# $latestVersion = $versionNumbers[0]
# $latestVersionUrl = "https://cdn.fork.dev/win/Fork-$latestVersion.exe"

$websiteContent = Invoke-WebRequest -Uri $WebsiteURL
$latestVersionUrl = $websiteContent.Links | Where-Object {$_.tagName -eq "A" -and ($_.outerHTML.Contains('"downloadBtn2Win"') -or $_.outerHTML.Contains('"downloadBtn1Win"'))} | Select-Object -First 1 -ExpandProperty href
# extract version from link
$latestVersion = [regex]::Match($latestVersionUrl, '.*Fork-(.*).exe').Groups[1].Value

return $latestVersion, "$latestVersionUrl"
