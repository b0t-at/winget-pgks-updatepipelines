if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = ${Env:PackageName}
$repo = ${Env:WebsiteURL}

Write-Host "Try to update $wingetPackage"

$latestVersionTag = gh release view --repo $repo --json tagName -q ".tagName"
$latestVersionName = gh release view --repo $repo --json name -q ".name"
$latestVersion = $latestVersionName -replace '.*?(\d+\.\d+\.\d+(.\d+)).*', '$1'
$assets = gh release view --repo $repo --json assets -q ".assets[] .url"
$msiAsset = $assets | Where-Object { $_ -like "*.msi" }


#### Standard Part ###

Write-Host "Version found: $latestVersion"

$prMessage = "Update version: $wingetPackage version $latestVersion"

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
    Write-Host "Fetching existing PRs"
    #gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    #gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

    $ExistingPRs = @($ExistingOpenPRs) + @($ExistingMergedPRs)    
    
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
    elseif ($ghCheck -eq 200) {
        Write-Host "Open PR for update"
        #Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
        #.\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$latestVersionUrl|x64" --prtitle $prMessage -t $gitToken
        Invoke-WebRequest "https://github.com/russellbanks/Komac/releases/download/v2.2.1/KomacPortable-x64.exe" -OutFile komac.exe
        .\komac.exe update --identifier $wingetPackage --version $latestVersion --urls $msiAsset -s -t $gitToken
    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}