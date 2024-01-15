if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
} else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = "FlipperDevicesInc.qFlipper"
$versionDirectoryUrl = "https://update.flipperzero.one/qFlipper/directory.json"

$versionDirectory = Invoke-RestMethod -Uri $versionDirectoryUrl 
$latestVersionDirectory = ($versionDirectory.channels | Where-Object id -eq "release").versions.version
$latestVersionUrl = (($versionDirectory.channels | Where-Object id -eq "release").versions.files | Where-Object { ($_.target -eq "windows/amd64") -and ($_.type -eq "installer") }).url

$foundMessage, $textVersion, $separator, $wingetVersions = (winget search --id $wingetPackage --source winget --versions).split("")

if ($wingetVersions) {
    $isNewerVersionAvailable = -not ($wingetVersions -match $latestVersionDirectory)
    if ($isNewerVersionAvailable) {
        $installerX64Url = $latestVersionUrl
        $ver = $latestVersionDirectory
        $prMessage = "Update version: $wingetPackage version $ver"

        # Check for existing PRs, if package has skip pr check set to false
        $ExistingPRs = gh pr list --search "$($wingetPackage) version $($ver) in:title draft:false" --state 'all' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
        if ($ExistingPRs.Count -gt 0) {
            $ExistingPRs | ForEach-Object {
                Write-Output "Found existing PR: $($_.title)"
                Write-Output "-> $($_.url)"
            }
        }
        else {     
            # getting latest wingetcreate file     
            Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
            .\wingetcreate.exe update $wingetPackage -s -v $ver -u "$installerX64Url" --prtitle $prMessage -t $gitToken
        }
    }
}
else { 
    Write-Output "$foundMessage - the app must be present in winget before it can be updated" 
}
