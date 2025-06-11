$Global:GITHUB_TOKEN = $null # Optional: For higher rate limits or private repos. $null for public.
# Can also be set as an environment variable and loaded here:
# $Global:GITHUB_TOKEN = $env:GITHUB_TOKEN

$Global:TARGET_REPO = "microsoft/winget-pkgs"  # Default repo, can be changed
# $PR_LABEL_NAME is set in the main execution block

function Get-GitHubApiResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [string]$Token = $Global:GITHUB_TOKEN
    )
    $headers = @{"Accept" = "application/vnd.github.v3+json" }
    if ($Token) {
        $headers["Authorization"] = "token $Token"
    }
    try {
        return Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get -ContentType "application/json"
    }
    catch {
        Write-Error "Error calling GitHub API ($Uri): $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorBody = $streamReader.ReadToEnd()
            $streamReader.Close()
            $errorResponse.Close()
            Write-Error "API Response Body: $errorBody"
        }
        throw
    }
}
function Get-PrsWithLabel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoOwner,
        [Parameter(Mandatory = $true)]
        [string]$RepoName,
        [Parameter(Mandatory = $true)]
        [string]$LabelName,
        [string]$Token = $Global:GITHUB_TOKEN
    )
    
    $allPrsData = [System.Collections.Generic.List[PSCustomObject]]::new()
    $page = 1
    $perPage = 100 # Max per page for GitHub API
    
    Write-Host "  Fetching PRs page $page..."
    while ($true) {
        $prsUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/pulls?state=open&labels=$([uri]::EscapeDataString($LabelName))&per_page=$perPage&page=$page"
        try {
            $currentPagePrs = Get-GitHubApiResponse -Uri $prsUrl -Token $Token
            
            if (-not $currentPagePrs -or $currentPagePrs.Count -eq 0) {
                break # No more PRs on this page or an empty array was returned
            }
            
            $allPrsData.AddRange($currentPagePrs)
            
            # Check if this was the last page (less items than per_page)
            if ($currentPagePrs.Count -lt $perPage) {
                break
            }
            
            $page++
            Write-Host "  Fetching PRs page $page..."
            Start-Sleep -Milliseconds 200 # Brief pause to respect API rate limits
        }
        catch [System.Net.WebException] {
            $response = $_.Exception.Response
            if ($response -and $response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
                Write-Warning "ERROR: Label '$LabelName' not found or no PRs with this label. Please check the label name."
                Write-Warning "Full Error: $($_.Exception.Message)"
                return @() # Return empty if label causes 404
            }
            elseif ($response -and $response.StatusCode -eq [System.Net.HttpStatusCode]::UnprocessableEntity) {
                # 422
                Write-Warning "ERROR: Validation failed. The label '$LabelName' might not exist or is misspelled."
                Write-Warning "Full Error: $($_.Exception.Message)"
                return @()
            }
            Write-Error "HTTP ERROR fetching PRs: $($_.Exception.Message)"
            if ($response) {
                $errorStream = $response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorStream)
                Write-Error "Response content: $($reader.ReadToEnd())"
                $reader.Close()
            }
            return @() # Return empty on other HTTP errors
        }
        catch {
            Write-Error "An unexpected error occurred while fetching PRs: $($_.Exception.Message)"
            return @() # Return empty on other errors
        }
    }
    return $allPrsData
}
function Get-PrFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrFilesUrl, # This should be the API URL for files of a specific PR
        [string]$Token = $Global:GITHUB_TOKEN
    )

    $allFilesData = [System.Collections.Generic.List[PSCustomObject]]::new()
    $page = 1
    $perPage = 100 # Max per page for PR files

    while ($true) {
        $pagedPrFilesUrl = "$PrFilesUrl`?per_page=$perPage&page=$page" # Note: backtick for '?' if in double quotes
        try {
            $currentPageFiles = Get-GitHubApiResponse -Uri $pagedPrFilesUrl -Token $Token
            
            if (-not $currentPageFiles -or $currentPageFiles.Count -eq 0) {
                break
            }
            
            $allFilesData.AddRange($currentPageFiles)
            
            if ($currentPageFiles.Count -lt $perPage) {
                break
            }
            $page++
            Start-Sleep -Milliseconds 200 # Brief pause
        }
        catch {
            Write-Error "Error fetching PR files from $($pagedPrFilesUrl): $($_.Exception.Message)"
            # Depending on desired robustness, you might want to retry or just skip this PR's files
            return @() # Return empty on error for this PR's files
        }
    }
    return $allFilesData
}

function Extract-ManifestPathsFromPrs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RepoFullName, # e.g., "microsoft/winget-pkgs"
        [Parameter(Mandatory = $true)]
        [string]$LabelName
    )
    
    if ($RepoFullName -notlike "*/*") {
        Write-Error "ERROR: Invalid repository format '$RepoFullName'. Expected 'owner/name'."
        return @()
    }
        
    $owner, $name = $RepoFullName.Split('/', 2)
    Write-Host "Fetching open PRs from $RepoFullName with label '$LabelName'..."
    
    $prs = Get-PrsWithLabel -RepoOwner $owner -RepoName $name -LabelName $LabelName -Token $Global:GITHUB_TOKEN
    
    if (-not $prs -or $prs.Count -eq 0) {
        Write-Host "No open PRs with label '$LabelName' found or an error occurred during fetch."
        return @()
    }

    Write-Host "$($prs.Count) PR(s) with label '$LabelName' found."
    
    $allManifestPaths = [System.Collections.Generic.HashSet[string]]::new()
    # Regex to identify Winget manifest files.
    # Looks for paths starting with 'manifests/' and ending with '.yaml' or '.yml'.
    $manifestRegex = '^manifests/.+\.(yaml|yml)$'

    foreach ($prSummary in $prs) {
        Write-Host "`nProcessing PR #$($prSummary.number): $($prSummary.title)"
        Write-Host "  URL: $($prSummary.html_url)"
        
        # The API URL for the PR's files is typically $prSummary.pull_request.url + "/files"
        # or $prSummary.url (which is the PR API URL) + "/files"
        $prFilesApiUrl = "$($prSummary.url)/files"
        
        try {
            $changedFiles = Get-PrFiles -PrFilesUrl $prFilesApiUrl -Token $Global:GITHUB_TOKEN
            $prManifestFilesCount = 0
            foreach ($fileInfo in $changedFiles) {
                $filePath = $fileInfo.filename
                if ($filePath -match $manifestRegex) {
                    # Status can be 'added', 'modified', 'removed', 'renamed'.
                    # For now, consider all mentioned manifest paths.
                    Write-Host "    Found manifest file: $filePath (Status: $($fileInfo.status))"
                    [void]$allManifestPaths.Add($filePath) # Add to HashSet, [void] suppresses output of Add method
                    $prManifestFilesCount++
                }
            }
            if ($prManifestFilesCount -eq 0) {
                Write-Host "    No manifest files found in the list of changed files for this PR."
            }
        }
        catch {
            Write-Error "  Error fetching files for PR #$($prSummary.number): $($_.Exception.Message)"
        }
    } # End foreach PR
            
    return $allManifestPaths | Sort-Object
}


function Get-IssuesWithLabel {
    param(
        [Parameter(Mandatory = $true)][string]$RepoFullName,
        [Parameter(Mandatory = $true)][string]$LabelName = "Error-Hash-Mismatch"
    )
    #$json = gh issue list --repo $RepoFullName --state open --label "$LabelName" --json "number,title,url,labels,body" --limit 300
    $json = gh issue list --repo $RepoFullName --state open --author ItzLevvie --label "$LabelName" --json "number,title,url,labels,body" --limit 300
    if (-not $json) { return @() }
    # Convert the JSON output to PowerShell objects
    return $json | ConvertFrom-Json
}

function Extract-ManifestPathsFromIssues {
    param(
        [Parameter(Mandatory = $true)][string]$RepoFullName,
        [Parameter(Mandatory = $true)][string]$LabelName
    )
    $issues = Get-IssuesWithLabel -RepoFullName $RepoFullName -LabelName $LabelName
    if (-not $issues) { Write-Host "No issues found."; return @() }
    $manifestRegex = 'manifests\/.+\.(yaml|yml)'
    $allManifests = @()
    foreach ($issue in $issues) {
        Write-Host "`nProcessing Issue #$($issue.number): $($issue.title)"
        # parse manifest paths from issue body
        $body = $issue.body
        $matches = [regex]::Matches($body, $manifestRegex)
        foreach ($match in $matches[0]) {
            $filePath = [system.uri]::UnescapeDataString($match.Value)
            Write-Host "    Found manifest file: $filePath"
            #[void]$allManifestPaths.Add($filePath)
            # add Package ID, Version, Issue ID and Path to Object
            $packageId = $filePath.split("/")[-1] -replace ".installer.yaml", ""
            $version = $filePath.split("/")[-2]
            $issueId = $issue.number
            #if anything is empty, break
            if (-not $packageId -or -not $version -or -not $issueId) {
                Write-Warning "    Error: Missing data in issue #$($issue.number) for file path: $filePath"
                break
            }
            $allManifests += [PSCustomObject]@{
                PackageId = $packageId
                Version   = $version
                IssueId   = $issueId
                FilePath  = $filePath
            }
        }
        #$allManifestPaths 
    }
    return $allManifests | Sort-Object
}

# --- Main Execution (Example for Script 2) ---
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    Write-Host "`n`n--- github_checker.ps1 ---"
    # User defines the label name here
    # Examples for labels in winget-pkgs repo:
    # "Needs-Author-Feedback", "Validation-Succeeded", "Yaml-Formatting-Errors", "Blocked"
    $PR_LABEL_TO_SEARCH = "Error-Hash-Mismatch" # Example, replace with an actual label
    
    # Optional: Set GitHub Token if not set globally or via environment variable
    # $Global:GITHUB_TOKEN = "your_github_token_here" 

    Write-Host "Searching for manifest paths in PRs with label: '$PR_LABEL_TO_SEARCH' in repo '$($Global:TARGET_REPO)'"
    $HashIssues = Extract-ManifestPathsFromIssues -RepoFullName "microsoft/winget-pkgs" -LabelName $PR_LABEL_TO_SEARCH
    
    if ($HashIssues) {
        Write-Host "`n--- Summary: All unique manifest paths found in PRs with label '$PR_LABEL_TO_SEARCH' ---" -ForegroundColor Green
        foreach ($pathItem in $HashIssues) {
            # Iterate through the sorted list
            # check for each item if there is already a open PR - if so, set property (potentionally not already there) "isInPR" to true
            $packageId = $pathItem.PackageId
            $version = $pathItem.Version
            $issueId = $pathItem.IssueId
            $filePath = $pathItem.FilePath
            $existingPR = Test-ExistingPRs -PackageId $packageId -Version $version -OnlyOpen
            if ($existingPR) {
                # set property "isInPR" to true
                $pathItem | Add-Member -MemberType NoteProperty -Name "isInPR" -Value $true
            }
            else {
                $pathItem | Add-Member -MemberType NoteProperty -Name "isInPR" -Value $false            
            }
        }
    }
    else {
        Write-Warning "`nNo manifest paths found for label '$PR_LABEL_TO_SEARCH' or an error occurred."
    }
}

$HashIssuesWithoutInPr = $HashIssues | Where-Object { $_.isInPR -eq $false }


### Replace body of PRs with "resolves: #$issueId"
#First, find all PRs opened by me
$myPRs = gh pr list --repo microsoft/winget-pkgs --author "@me" --state open --json "number,title,state,author,url,closingIssuesReferences"
$myPRs = $myPRs | ConvertFrom-Json
$myunlinkedPRs = $myPRs | Where-Object {!$_.closingIssuesReferences}

foreach ($pr in $myunlinkedPRs) {
    foreach ($changedManifest in $HashIssues | Where-Object { $_.isInPR -eq $false }) {
        $titleMatch = $pr.title -like "*$($changedManifest.PackageId)*" -and $pr.title -like "*$($changedManifest.Version)*"
        if ($titleMatch) {
            $newBody = "resolves #$($changedManifest.IssueId)"
            # if PR is to remove a package, add a line to body "a newer version with the same URL is already in winget"
            if ($changedManifest.FilePath -like "*remove*") {
                $newBody += "`nA newer version with the same URL is already in winget."
            }
            Write-Host "Updating PR #$($pr.number) with body: $newBody"
            gh pr edit $pr.number --repo microsoft/winget-pkgs --body "$newBody"
        }
    }

}

