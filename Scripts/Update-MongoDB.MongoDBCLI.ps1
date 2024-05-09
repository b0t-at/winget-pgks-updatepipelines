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

$PackageFilter = "mongocli"

Write-Host "Try to update $wingetPackage"

# Download the webpage
$website = Invoke-WebRequest -Uri $url

# Extract the content of the webpage
$content = $website.Content

# Find all strings that look like links and end with .msi
$links = $content | Select-String -Pattern 'https?://[^"]+' -AllMatches | % { $_.Matches } | % { $_.Value }
$msilinks = $links | Select-String -Pattern 'https?://[^\s]*\.msi' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }



$Packagelinks = $msilinks | Select-String -Pattern "https?://[^\s]*$PackageFilter[^\s]*\.msi" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }| Where-Object { $_ -notmatch "$PackageFilter-isolated|$PackageFilter-readonly" }
# Extract versions from the links
$versions = $Packagelinks | ForEach-Object { $_ -match '(\d+\.\d+\.\d+(-rc\d*|-beta\d*)?)' | Out-Null; $matches[1] }

# Exclude release candidates
$stableVersions = $versions | Where-Object { $_ -notmatch '(-rc|beta)' }

# Sort the versions and get the latest one
$latestVersion = $stableVersions | Sort-Object {[Version]$_} | Select-Object -Last 1
$latestVersionUrl = $Packagelinks | Where-Object { $_ -match $latestVersion }
Write-Host "Version found: $PackageFilter  $latestVersion. URL: $latestVersionUrl"


Write-Host "Version found: $latestVersion"

$prMessage = "Update version: $wingetPackage version $latestVersion"

$ghVersionURL = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/$latestVersion/$wingetPackage.yaml"
$ghCheckURL = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/"


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
    elseif ($ghCheck.StatusCode -eq 200) {
        Write-Host "Open PR for update"
        Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
        .\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$latestVersionUrl|x64" --prtitle $prMessage -t $gitToken
    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}

