if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = "Loupedeck.Loupedeck"

# check current version in winget
$foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = "https://download.loupedeck.com/software/latest-win"
#create directory downloads and change into it
$DownloadFileName = "latest-win.exe"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName
$file = Get-ChildItem -Path $DownloadFileName
$versionInfo = $file.VersionInfo.ProductVersion

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

Write-Host "Found latest version: $versionInfo"

if ($wingetVersions.Contains($versionInfo)) {
    Write-Host "No new version found"
    exit 0
}

$fullDownloadURL = "https://download.loupedeck.com/software/latest/LoupedeckInstaller_" + $versionInfo + ".exe"

# check if full download URL is valid
$fullDownloadURLResponse = Invoke-WebRequest -Uri $fullDownloadURL -UseBasicParsing -Method Head
if ($fullDownloadURLResponse.StatusCode -ne 200) {
    Write-Host "Full download URL is not valid"
    exit 1
}

# Check for existing PRs
$ExistingPRs = gh pr list --search "$($wingetPackage) version $($versionInfo) in:title draft:false" --state 'all' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

if ($wingetVersions -and ($wingetVersions -notmatch $versionInfo) -and ($ExistingPRs.Count -eq 0)) {
    gh repo sync $Env:WINGET_PKGS_FORK_REPO -b main
    $prMessage = "Update version: $wingetPackage version $versionInfo"
    # getting latest wingetcreate file     
    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    #architecture workaround: https://github.com/microsoft/winget-create/blob/main/doc/update.md
    .\wingetcreate.exe update $wingetPackage -s -v $versionInfo -u "$fullDownloadURL|x64" --prtitle $prMessage -t $gitToken
}
else { 
    Write-Host "$foundMessage"
    if ($ExistingPRs.Count -gt 0) {
        $ExistingPRs | ForEach-Object {
            Write-Host "Found existing PR: $($_.title)"
            Write-Host "-> $($_.url)"
        }
    }
}
