$downloadPage = "https://repo.jellyfin.org/files/server/windows/stable/"
$releases = (Invoke-WebRequest -Uri $downloadPage).Links
$allReleases = $releases `
    | Sort-Object -Property { [System.Version]::Parse($_.href.TrimStart('v').TrimEnd('/')) } -Descending -ErrorAction SilentlyContinue

foreach($release in $allReleases) {
$releasePage = "$downloadPage$($release.href)amd64"
$installerName = (Invoke-WebRequest -Uri $releasePage/).Links | Where-Object { $_.href -like '*_windows-x64.exe' } | Select-Object -ExpandProperty href
if($null -eq $installerName) {
    continue
}
$latestVersionUrl = "$releasePage/$installerName"
$latestVersion = $installerName.Split('_')[1]
break
}


return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
  }