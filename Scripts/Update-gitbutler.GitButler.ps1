if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = "Gitbutler.GitButler"

# Follow redirect of https://app.gitbutler.com/downloads/release/windows/x86_64/msi
$website = "https://app.gitbutler.com/downloads/release/windows/x86_64/msi"
$absolutURL=[System.Net.HttpWebRequest]::Create($website).GetResponse().ResponseUri.AbsoluteUri

# regex to check if variable absolutURL is valid URL
$regex = "^(http|https)://([\w-]+.)+[\w-]+(/[\w- ./?%&=])?$"
if ($absolutURL -match $regex) {
    $latestVersionUrl = $absolutURL
}
else {
    Write-Host "URL is not valid"
    exit 1
}


# get full name of file from link
$fileName = $latestVersionUrl.Split("/")[-1]

# Get Version via Regex. The version is the part betweet "GitButler_" and "_x64"
$latestVersion = $fileName -replace ".*GitButler_(.*)_(x64|x86).*", '$1'


$prMessage = "Update version: $wingetPackage version $latestVersion"

$foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

# Check for existing versions in winget
if ($wingetVersions -contains $latestVersion) {
    Write-Output "Latest version of $wingetPackage $latestVersion is already present in winget."
}
else {
    # Check for existing PRs
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

    $ExistingPRs = $ExistingOpenPRs + $ExistingMergedPRs
    
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
        Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
        .\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$latestVersionUrl" --prtitle $prMessage -t $gitToken
    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}
