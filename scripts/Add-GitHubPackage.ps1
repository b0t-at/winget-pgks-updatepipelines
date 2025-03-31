param(
    [Parameter(Mandatory=$true)][string]$PackageId
)

# get the script location
$scriptPath = $MyInvocation.MyCommand.Path
#check if PackageID is already in workflow file
$githubReleasesYml = Get-Content -Path "$scriptPath/../../.github/workflows/github-releases.yml"
if ($githubReleasesYml -match $PackageId) {
    Write-Host "PackageId already in workflow"
    exit 0
}

Install-Komac

$versionTemplate = "{VERSION}"

# get the version from the output
$version = Get-LatestVersionInWinget -PackageId $PackageId
$packagePath = $PackageId -replace '\.', '/'
$firstChar = $PackageId[0].ToString().ToLower()
$fullInstallerDetails = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/microsoft/winget-pkgs/refs/heads/master/manifests/$firstChar/$packagePath/$version/$PackageId.installer.yaml" -UseBasicParsing).Content
# filter for lines containing "Installer-URL"
$urls = @()
$githubRepository = $null
$fullInstallerDetails -split "`n" | Where-Object { $_ -like "*InstallerURL:*" } | ForEach-Object {
    # split the line by the first ":"
    $split = $_.Split(":", 2)
    # get the second part of the split
    $url = $split[1].Trim()
    # replace version with template
    $url = $url.Replace($version, $versionTemplate)
    # add the url to the list
    $urls += $url
    if($githubRepository -eq $null -and $url -like "https://github.com/*"){
        $githubRepository = $url.Split("/")[3..4] -join "/"
    }
}

$finalTemplateUrlString = $urls -join " "

#check if a newer version is available in the github repository
$newestGitHubRelease = gh release list --repo $githubRepository --json name,tagName,publishedAt,isLatest,isPrerelease | ConvertFrom-Json | Where-Object { $_.isPrerelease -eq $false } | Sort-Object -Property publishedAt -Descending | Select-Object -First 1
$newestGitHubVersion = $newestGitHubRelease.tagName.TrimStart("v")
if($newestGitHubVersion -ne $version){
    $urlsWithVersion = ($urls | ForEach-Object { $_.Replace($versionTemplate, $newestGitHubVersion) })
    komac update "$PackageId" --version "$newestGitHubVersion" --urls $urlsWithVersion --dry-run --skip-pr-check
} else {
    Write-Host "No new version available"
    #exit 0
}

if([string]::IsNullOrWhiteSpace($PackageId) -or [string]::IsNullOrWhiteSpace($githubRepository) -or [string]::IsNullOrWhiteSpace($finalTemplateUrlString)) {
    Write-Host "PackageId, GitHubRepository or TemplateUrl is empty"
    exit 1
}


$releaseBlock = @"
      - id: "$PackageId"
            repo: "$githubRepository"
            url: "$finalTemplateUrlString"  
"@


# append the releaseblock to the github-releases.yml file before the steps block
$githubReleasesYml = $githubReleasesYml -replace "steps:", "$releaseBlock`n    steps:"
$githubReleasesYml | Set-Content -Path "$scriptPath/../../.github/workflows/github-releases.yml"

Write-Host "----------------------"
Write-Host $releaseBlock