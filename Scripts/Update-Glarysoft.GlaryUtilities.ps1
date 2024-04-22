if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = "Glarysoft.GlaryUtilities"


# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = "https://download.glarysoft.com/gusetup.exe"
#create directory downloads and change into it
$DownloadFileName = "gusetup.exe"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName
$file = Get-ChildItem -Path $DownloadFileName
$versionInfo = $file.VersionInfo.ProductVersionRaw

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

Write-Host "Found latest version: $versionInfo"

$latestVersion = $versionInfo

$fullDownloadURL = $latestVersionUrl

$prMessage = "Update version: $wingetPackage version $latestVersion"

$foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

# Check for existing versions in winget
if ($wingetVersions -contains $latestVersion) {
    Write-Output "Latest version of $wingetPackage $latestVersion is already present in winget."
    exit 0
}
else {
    # Check for existing PRs
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

    $ExistingPRs = $ExistingOpenPRs += $ExistingMergedPRs

    # TODO Check if PR is already merged, if so exit

    # TODO if PR from us is already open, update PR with new version

    # TODO if PR is closed, not from us and no PR got merged, create new PR

    # TODO if PR is closed, from us and no PR got merged, throw error

    if ($ExistingPRs.Count -gt 0) {
        Write-Output "$foundMessage"
        $ExistingPRs | ForEach-Object {
            Write-Output "Found existing PR: $($_.title)"
            Write-Output "-> $($_.url)"
        }
    }
    elseif ($wingetVersions -and ($wingetVersions -notmatch $latestVersion)) {
        Write-Output "Downloading wingetcreate and open PR for $wingetPackage Version $latestVersion"
        Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
        .\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$latestVersionUrl" --prtitle $prMessage -t $gitToken
    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}
