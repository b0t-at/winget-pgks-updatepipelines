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
    $ExistingPRs = gh pr list --search "$($wingetPackage) version $($latestVersion) in:title draft:false" --state 'all' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json

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
