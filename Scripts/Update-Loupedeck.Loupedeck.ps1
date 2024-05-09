if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$url = ${Env:WebsiteURL}
$wingetPackage = ${Env:PackageName}

# check current version in winget
$foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = $url
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

# extract major and minor version e.g. 5.9 from 5.9.10
$majorMinorVersion = $versionInfo -replace '\.\d+$'
$fullDownloadURL = "https://5145542.fs1.hubspotusercontent-na1.net/hubfs/5145542/Knowledge%20Base/LD%20Software%20Downloads/$majorMinorVersion/LoupedeckInstaller_" + $versionInfo + ".exe"

Write-Host "Full download URL: $fullDownloadURL"

# check if full download URL is valid
$fullDownloadURLResponse = Invoke-WebRequest -Uri $fullDownloadURL -UseBasicParsing -Method Head
if ($fullDownloadURLResponse.StatusCode -ne 200) {
    Write-Host "Full download URL is not valid"
    exit 1
}

    # Check for existing PRs
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

    $ExistingPRs = @($ExistingOpenPRs) + @($ExistingMergedPRs)    
if ($wingetVersions -and ($wingetVersions -notmatch $versionInfo) -and ($ExistingPRs.Count -eq 0)) {
    $prMessage = "Update version: $wingetPackage version $versionInfo"
    #architecture workaround: https://github.com/microsoft/winget-create/blob/main/doc/update.md
    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
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
