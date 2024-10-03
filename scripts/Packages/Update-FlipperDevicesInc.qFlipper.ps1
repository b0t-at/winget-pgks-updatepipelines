


$versionDirectory = Invoke-RestMethod -Uri $WebsiteURL 
$latestVersionDirectory = ($versionDirectory.channels | Where-Object id -eq "release").versions.version
$latestVersionUrl = (($versionDirectory.channels | Where-Object id -eq "release").versions.files | Where-Object { ($_.target -eq "windows/amd64") -and ($_.type -eq "installer") }).url

return $latestVersionDirectory, $latestVersionUrl