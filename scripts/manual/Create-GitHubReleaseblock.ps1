# take version and releaseurl as parameters
# param(
#     [string]$PackageId,
#     [string]$Releaseurl
# )

$PackageId = "AdGuard.AdGuardHome"

Import-Module Microsoft.WinGet.Client
$versionTemplate = "{VERSION}"

# get latest winget version for the package
$wingetShow = winget show --id $PackageId --exact
# get the version from the output
$version = ($wingetShow | Where-Object { $_ -like "Version:*" }).Split(":")[1].Trim()
# filter for lines containing "Installer-URL"
$urls = @()
$githubRepository = $null
$wingetShow | Where-Object { $_ -like "*Installer-URL:*" } | ForEach-Object {
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
    $urlsWithVersion = $urls | ForEach-Object { $_.Replace($versionTemplate, $newestGitHubVersion) }
    komac update  --version "$version" --urls "$urlsWithVersion" --dry-run "$PackageId"
} else {
    Write-Host "No new version available"
}



$releaseBlock = @"
          - id: "$PackageId"
            repo: "$githubRepository"
            url: "$finalTemplateUrlString"  
"@
Write-Host "----------------------"
Write-Host $releaseBlock