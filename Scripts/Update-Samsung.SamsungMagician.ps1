if ($Env:GITHUB_TOKEN) {
    Write-Host 'GITHUB_TOKEN detected'
    $gitToken = ${Env:GITHUB_TOKEN}
}
else {
    Write-Host 'GITHUB_TOKEN not detected'
    exit 1
}

$wingetPackage = "Samsung.SamsungMagician"

# scrap website for download link https://semiconductor.samsung.com/consumer-storage/support/tools/
$website = "https://www.samsung.com/semiconductor/minisite/ssd/download/tools/"
$websiteContent = Invoke-WebRequest -Uri $website

$links = $websiteContent.Links | Where-Object { $_.href -like "*.exe" -and $_.href -like "*Samsung_Magician_Installer*" }

$latestVersionUrl = $links[0].href


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
        gh repo sync $Env:WINGET_PKGS_FORK_REPO -b main
        .\wingetcreate.exe update $wingetPackage -s -v $ver -u "$latestVersionUrl" --prtitle $prMessage -t $gitToken
    }
    else { 
        Write-Output "$foundMessage"
        Write-Output "No existing PRs found. Check why wingetcreate has not run."
    }
}
