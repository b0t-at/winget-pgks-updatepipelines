if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = ${Env:PackageName}
$url = ${Env:WebsiteURL}


# download latest version from loupedeck.com and get version by filename
$latestVersionUrl = $url
#create directory downloads and change into it
$DownloadFileName = "storage-executive-win-64.zip"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName

# Unzip the downloaded file
$UnzipPath = "."
Expand-Archive -Path $DownloadFileName -DestinationPath $UnzipPath

$file = Get-ChildItem -Path . -Filter "*.exe"
$versionInfo = $file.VersionInfo.ProductVersion

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

Write-Host "Found latest version: $versionInfo"

$latestVersion = $versionInfo

$ghVersionURL = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/$latestVersion/$wingetPackage.yaml"
$ghCheckURL = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/"
$prMessage = "Update version: $wingetPackage version $latestVersion"


# Check if package is already in winget
$ghCheck = Invoke-WebRequest -Uri $ghCheckURL -Method Head -SkipHttpErrorCheck 
if ($ghCheck.StatusCode -eq 404) {
    Write-Output "Packet not yet in winget. Please add new Packet manually"
    exit 1
} 

$ghVersionCheck = Invoke-WebRequest -Uri $ghVersionURL -Method Head -SkipHttpErrorCheck  

if ($ghVersionCheck.StatusCode -eq 200) {
    Write-Output "Latest version of $wingetPackage $latestVersion is already present in winget."
    exit 0
}
else {
    # Check for existing PRs
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

    $ExistingPRs = @($ExistingOpenPRs) + @($ExistingMergedPRs)    

    if ($ExistingPRs.Count -gt 0) {
        Write-Output "$foundMessage"
        $ExistingPRs | ForEach-Object {
            Write-Output "Found existing PR: $($_.title)"
            Write-Output "-> $($_.url)"
        }
    }
    elseif ($ghCheck.StatusCode -eq 200) {
        Write-Output "Downloading wingetcreate and open PR for $wingetPackage Version $latestVersion"
    #    Invoke-WebRequest "https://github.com/russellbanks/Komac/releases/download/v2.2.1/KomacPortable-x64.exe" -OutFile komac.exe
    #    .\komac.exe update --identifier $wingetPackage --version $latestVersion --urls $latestVersionUrl -s -t $gitToken
    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    .\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$latestVersionUrl|x64" --prtitle $prMessage -t $gitToken

    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}
