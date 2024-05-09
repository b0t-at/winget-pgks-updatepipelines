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
$latestversion = $versionInfo
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

$ghVersionURL = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$wingetPackage.Substring(0, 1).ToLower()/$($wingetPackage.replace(".","/"))/$latestVersion/$wingetPackage.yaml"
$ghCheckURL = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$wingetPackage.Substring(0, 1).ToLower()/$($wingetPackage.replace(".","/"))/"


# Check if package is already in winget
$ghCheck = Invoke-WebRequest -Uri $ghCheckURL -Method Head -SkipHttpErrorCheck 
if ($ghVersionCheck.StatusCode -eq 404) {
    Write-Output "Packet not yet in winget. Please add new Packet manually"
    exit 1
} 

$ghVersionCheck = Invoke-WebRequest -Uri $ghVersionURL -Method Head -SkipHttpErrorCheck  

#$foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

if ($ghVersionCheck.StatusCode -eq 200) {
    Write-Output "Latest version of $wingetPackage $latestVersion is already present in winget."
    exit 0
}
else {
    # Check for existing PRs
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

    $ExistingPRs = @($ExistingOpenPRs) + @($ExistingMergedPRs)    
    # TODO Check if PR is already merged, if so exit

    # TODO if PR from us is already open, update PR with new version

    # TODO if PR is closed, not from us and no PR got merged, create new PR

    # TODO if PR is closed, from us and no PR got merged, throw error

    if ($ExistingPRs.Count -gt 0) {
        Write-Output "Version already in winget"
        $ExistingPRs | ForEach-Object {
            Write-Output "Found existing PR: $($_.title)"
            Write-Output "-> $($_.url)"
        }
    }
    elseif ($ghCheck -eq 200) {
        Write-Output "Downloading wingetcreate and open PR for $wingetPackage Version $latestVersion"
        Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
        .\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$latestVersionUrl" --prtitle $prMessage -t $gitToken
    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}
