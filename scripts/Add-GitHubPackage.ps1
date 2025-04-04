param(
    [Parameter(Mandatory = $true)][string]$PackageId
)

function get-yamlSorted {
    param(
        [Parameter(Mandatory = $true)]$content
    )

    #import-module powershell-yaml
    # Extract all comment lines (lines starting with '#') in the original order.
    $commentLines = $content.Split("`n") | where-object { $_.TrimStart().StartsWith("#") }

    # Remove all comment lines from the main content.
    $contentWithoutComments = $content.Split("`n")  | where-object { -not $_.TrimStart().StartsWith("#") }

    # Regex pattern to capture each YAML item block.
    # It uses multiline mode so that it captures from a line starting with "- id:" up until the next occurrence or end of file.
    $pattern = '(?s)(^\s*- id:.*?)(?=^\s*- id:|\z)'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

    # Extract each block and trim it.
    $blocks = foreach ($match in $matches) {
        $match.Groups[1].Value.TrimEnd()
    }

    # Sort the blocks by extracting the ID from the first line.
    # Assumes the id line is in the format: - id: "SomeID"
    $sortedBlocks = $blocks | Sort-Object -Property {
        $m = [regex]::Match($_, '^          - id:\s*"(.*?)"', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        if ($m.Success) { $m.Groups[1].Value } else { $_ }
    }
    $contentWithoutComments = ($sortedBlocks.Split("`n")  | where-object { -not $_.TrimStart().StartsWith("#") }) -join "`n"

    # Reassemble the sorted blocks into a complete string.
    #$output = $sortedBlocks -join "`n"

    $output = $contentWithoutComments + "`n" + ($commentLines -join "`n")

    return $output
}

# get the script location
$scriptPath = $MyInvocation.MyCommand.Path
$ymlPath = "$scriptPath/../../github-releases-monitored.yml"
#check if PackageID is already in workflow file
$githubReleasesYml = Get-Content -Path "$ymlPath" -raw
if ($githubReleasesYml -match $PackageId) {
    Write-Host "PackageId already in workflow"
    exit 0
}

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
    $url = $url.Replace($version.TrimStart("v","V"), $versionTemplate)
    # add the url to the list
    $urls += $url
    if ($githubRepository -eq $null -and $url -like "https://github.com/*") {
        $githubRepository = $url.Split("/")[3..4] -join "/"
    }
}

$finalTemplateUrlString = $urls -join " "

#check if a newer version is available in the github repository
$newestGitHubRelease = gh release list --repo $githubRepository --json "name,tagName,publishedAt,isLatest,isPrerelease" | ConvertFrom-Json | Where-Object { $_.isPrerelease -eq $false } | Sort-Object -Property publishedAt -Descending | Select-Object -First 1
$newestGitHubVersion = $newestGitHubRelease.tagName.TrimStart("v","V")
if ($newestGitHubVersion -ne $version) {
    Install-Komac
    $urlsWithVersion = ($urls | ForEach-Object { $_.Replace($versionTemplate, $newestGitHubVersion) })

    komac update "$PackageId" --version "$newestGitHubVersion" --urls $urlsWithVersion --dry-run --skip-pr-check
    # break if komac update fails
    if ($LASTEXITCODE -ne 0) {
        Write-Host "komac update failed"
        write-host "Error: $($_.Exception.Message)"

        exit 1
    }
    
}
else {
    Write-Host "No new version available"
    exit 0
}

if ([string]::IsNullOrWhiteSpace($PackageId) -or [string]::IsNullOrWhiteSpace($githubRepository) -or [string]::IsNullOrWhiteSpace($finalTemplateUrlString)) {
    Write-Host "PackageId, GitHubRepository or TemplateUrl is empty"
    exit 1
}

$releaseBlock = @"
          - id: "$PackageId"
            repo: "$githubRepository"
            url: "$finalTemplateUrlString"  
"@


# append the releaseblock to the github-releases.yml file before the steps block
$content = $githubReleasesYml + $releaseBlock

$output = get-yamlSorted -content $content
#$output = get-yamlSorted -content $output
$output | Set-Content -Path "$ymlPath"
(Get-Content -Path "$ymlPath") | Where-Object {$_.trim() -ne "" } | Set-Content -Path "$ymlPath"




Write-Host "----------------------"
Write-Host $releaseBlock