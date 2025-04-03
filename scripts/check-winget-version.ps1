<# 
.SYNOPSIS
    Identifies winget packages with GitHub installer URLs that might need updates.
.DESCRIPTION
    This script analyzes the winget-pkgs repository to find packages that use GitHub URLs
    in their installers, compares their current version with the latest release
    available on GitHub, and outputs the results to a CSV file.
    
    The script only keeps the latest version of each package for comparison.
.PARAMETER OutputPath
    Path where the CSV file will be saved. Default is "winget-github-versions.csv".
.PARAMETER TempDir
    Temporary directory for cloning the winget-pkgs repository.
.PARAMETER GitHubToken
    GitHub personal access token to avoid rate limiting. Optional.
#>
param (
    [string]$OutputPath = "winget-github-versions.csv",
    [string]$TempDir = "$env:TEMP\winget-analysis-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [string]$GitHubToken = ""
)

# Function to clone the winget-pkgs repository
function Clone-WingetRepo {
    param (
        [string]$DestinationPath
    )
    
    Write-Host "Cloning winget-pkgs repository to $DestinationPath..."
    
    # Ensure destination directory exists and is empty
    if (Test-Path $DestinationPath) {
        Remove-Item -Path $DestinationPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    
    # Use shallow clone to improve performance
    $process = Start-Process -FilePath "git" -ArgumentList "clone", "--depth", "1", 
    "https://github.com/microsoft/winget-pkgs.git", $DestinationPath -NoNewWindow -PassThru -Wait
    
    if ($process.ExitCode -ne 0) {
        throw "Failed to clone the winget-pkgs repository (Exit code: $($process.ExitCode))"
    }
    
    Write-Host "Repository cloned successfully"
}

# Function to extract package information from installer YAML file
function Get-PackageInfoFromInstallerFile {
    param (
        [System.IO.FileInfo]$InstallerFile
    )
    
    $content = Get-Content -Path $InstallerFile.FullName -Raw
    $packageId = $null
    $version = $null
    $installerUrl = $null
    
    # Extract PackageIdentifier
    if ($content -match '(?m)^PackageIdentifier\s*:\s*(.+?)$') {
        $packageId = $matches[1].Trim()
    }
    
    # Extract PackageVersion
    if ($content -match '(?m)^PackageVersion\s*:\s*(.+?)$') {
        $version = $matches[1].Trim()
    }
    
    # Extract first installer URL
    # Look for InstallerUrl field in various formats
    if ($content -match '(?m)InstallerUrl\s*:\s*(.+?)(\r?\n|\z)') {
        $installerUrl = $matches[1].Trim()
        # Remove quotes if present
        $installerUrl = $installerUrl -replace '^[''"]|[''"]$', ''
    }
    
    # If we failed to extract essential information, skip this file
    if (-not $packageId -or -not $version -or -not $installerUrl) {
        Write-Verbose "Missing required information in $($InstallerFile.FullName)"
        return $null
    }
    
    return @{
        PackageId    = $packageId
        Version      = $version
        InstallerUrl = $installerUrl
        FilePath     = $InstallerFile.FullName
    }
}

# Function to compare version strings correctly
function Compare-Versions {
    param (
        [string]$VersionA,
        [string]$VersionB
    )
    
    # Handle special cases
    if ($VersionA -eq $VersionB) { return 0 }
    if ([string]::IsNullOrEmpty($VersionA)) { return -1 }
    if ([string]::IsNullOrEmpty($VersionB)) { return 1 }
    
    # Parse versions into components
    $componentsA = $VersionA -split '[\.\-\+]'
    $componentsB = $VersionB -split '[\.\-\+]'
    
    # Compare components one by one
    for ($i = 0; $i -lt [Math]::Max($componentsA.Count, $componentsB.Count); $i++) {
        # If we've reached the end of version A, B is greater
        if ($i -ge $componentsA.Count) { return -1 }
        # If we've reached the end of version B, A is greater
        if ($i -ge $componentsB.Count) { return 1 }
        
        $compA = $componentsA[$i]
        $compB = $componentsB[$i]
        
        # Try to parse as integers for numerical comparison
        $isIntA = [int]::TryParse($compA, [ref]$null)
        $isIntB = [int]::TryParse($compB, [ref]$null)
        
        # If both components are numeric, compare as numbers
        if ($isIntA -and $isIntB) {
            $numA = [int]$compA
            $numB = [int]$compB
            if ($numA -ne $numB) {
                return $numA.CompareTo($numB)
            }
        }
        # If only one is numeric, numeric is greater
        elseif ($isIntA) {
            return 1
        }
        elseif ($isIntB) {
            return -1
        }
        # Otherwise compare as strings
        else {
            $stringCompare = [string]::Compare($compA, $compB, $true)
            if ($stringCompare -ne 0) {
                return $stringCompare
            }
        }
    }
    
    # If we get here, the versions are equal in all compared components
    return 0
}

# Function to extract GitHub owner and repo from URL
function Get-GitHubInfo {
    param (
        [string]$Url
    )
    
    # Handle empty URLs
    if ([string]::IsNullOrEmpty($Url)) {
        return $null
    }
    
    # Match GitHub URLs for owner/repo
    if ($Url -match 'github\.com/([^/]+)/([^/]+)') {
        $owner = $matches[1]
        # Remove .git and any query parameters
        $repo = $matches[2] -replace '\.git$', '' -replace '\?.*$', '' -replace '#.*$', ''
        
        return @{
            Owner   = $owner
            Repo    = $repo
            FullUrl = $Url
        }
    }
    
    return $null
}

# Function to get the latest release from GitHub
function org_Get-LatestGitHubRelease {
    param (
        [string]$Owner,
        [string]$Repo,
        [string]$Token = ""
    )
    
    try {
        # Set up API request headers
        $headers = @{
            "Accept"     = "application/vnd.github.v3+json"
            "User-Agent" = "WinGet-Version-Checker"
        }
        
        if (-not [string]::IsNullOrEmpty($Token)) {
            $headers["Authorization"] = "token $Token"
        }
        
        # Try the latest release endpoint first
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
        
        try {
            $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
            return $response.tag_name
        }
        catch {
            # If latest release endpoint fails, try listing all releases
            if ($_.Exception.Response.StatusCode -eq 404) {
                $apiUrl = "https://api.github.com/repos/$Owner/$Repo/releases"
                
                try {
                    $releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
                    
                    if ($releases.Count -gt 0) {
                        return $releases[0].tag_name
                    }
                    else {
                        # If no releases found, try tags as a fallback
                        $apiUrl = "https://api.github.com/repos/$Owner/$Repo/tags"
                        $tags = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
                        
                        if ($tags.Count -gt 0) {
                            return $tags[0].name
                        }
                    }
                }
                catch {
                    throw "Failed to get releases or tags: $_"
                }
            }
            else {
                throw $_
            }
        }
        
        return "Unknown"
    }
    catch {
        Write-Warning "Failed to get latest release for $Owner/$Repo : $_"
        return "ratelimit"
    }
}

function Get-LatestGitHubRelease {
    param (
        [string]$Owner,
        [string]$Repo,
        [string]$Token = ""
    )
    
    # Ensure the GH CLI is available
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) is not installed or not available in the PATH."
    }
    
    $repository = "$Owner/$Repo"
    # Use gh release view to fetch the latest release tagName as JSON, then extract the tagName using jq filter.
    $cmd = "gh release view --repo $repository --json tagName --jq .tagName"
    
    try {
        $tag = Invoke-Expression $cmd
        # If no tag found from releases, try the repository view for a latest release fallback.
        if (-not $tag -or $tag -eq "") {
            $cmdFallback = "gh repo view $repository --json latestRelease --jq .latestRelease.tagName"
            $tag = Invoke-Expression $cmdFallback
        }
        
        if (-not $tag -or $tag -eq "") {
            return "Unknown"
        }
        return $tag
    }
    catch {
        Write-Warning "Failed to get latest release using gh cli for $repository : $_"
        return "ratelimit"
    }
}

# Function to clean version strings for comparison
function Get-CleanVersion {
    param (
        [string]$Version
    )
    
    if ([string]::IsNullOrEmpty($Version)) {
        return ""
    }
    
    # Remove common prefixes like 'v', 'release-', etc.
    $cleanVersion = $Version -replace '^[vV]', ''
    $cleanVersion = $cleanVersion -replace '^release[-_]', ''
    $cleanVersion = $cleanVersion -replace '^RELEASE\.', ''
    
    return $cleanVersion
}

# Main execution
try {
    # Set TLS 1.2 for API requests
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Start timing
    $startTime = Get-Date
    Write-Host "Starting analysis at $startTime"
    
    # Clone the repo
    Clone-WingetRepo -DestinationPath $TempDir
    
    # Find all installer YAML files
    $manifestsDir = Join-Path -Path $TempDir -ChildPath "manifests"
    Write-Host "Searching for installer files in $manifestsDir..."
    
    $installerFiles = Get-ChildItem -Path $manifestsDir -Recurse -File | 
        Where-Object { $_.Name -match '\.installer\.(yaml|yml)$' }
    
    Write-Host "Found $($installerFiles.Count) installer files. Processing..."
    
    # Process installer files
    $packageData = @{}
    $fileCount = 0
    $totalFiles = $installerFiles.Count
    
    # Set up progress bar parameters
    $progressParams = @{
        Activity        = "Processing installer files"
        Status          = "0" + "/" + "$totalFiles Complete"
        PercentComplete = 0
    }

    $syncHash = [hashtable]::Synchronized(@{ Count = 0 })

    # Get the function's definition *as a string*
    $funcDef = ${function:Get-PackageInfoFromInstallerFile}.ToString()

    $installerFiles | ForEach-Object -ThrottleLimit 5 -Parallel {
        $syncCopy = $using:syncHash
        $file = $_
        #$fileCount++
        ${function:Get-PackageInfoFromInstallerFile} = $using:funcDef
        # Update progress every 100 files for performance
        $percent = [math]::Min(100, [math]::Round(($($syncCopy.Count) / $using:totalFiles) * 100))
        #$progressParams.Status = "$($syncCopy.Count)" + "/" + "$totalFiles Complete"
        #$progressParams.PercentComplete = $percent
        #$progressParams.Activity = "Processing installer files"
        #Write-Progress @progressParams
        Write-Progress -Activity "Processing files" -Status ("$($syncCopy.Count)" + "/" + "$using:totalFiles Complete") -PercentComplete $percent

        $packageInfo = Get-PackageInfoFromInstallerFile -InstallerFile $file
        
        if ($packageInfo) {
            $packageId = $packageInfo.PackageId
            $packageData = $using:packageData
            
            # If this is the first time seeing this package, initialize it
            $packageData[$packageId + " " + $packageInfo.Version] = @{
                PackageID      = $packageId
                CurrentVersion = $packageInfo.Version
                InstallerUrl   = $packageInfo.InstallerUrl
                FilePath       = $packageInfo.FilePath
            }
            #$packageData += $packageData
        }
        
        $syncCopy.Count++
    }

    
    # Otherwise, compare versions and keep the highest one
    else {
        $highest = (get-stnumericalSorted $packageInfo.Version, $packageData[$packageId].CurrentVersion -Descending) | Select-Object -first 1
                
        if ($packageData[$packageId].CurrentVersion -ne $highest) {
            $packageData[$packageId] = @{
                CurrentVersion = $packageInfo.Version
                InstallerUrl   = $packageInfo.InstallerUrl
                FilePath       = $packageInfo.FilePath
            }
        }
    }



    Write-Progress -Activity "Processing installer files" -Completed
    
    Write-Host "Processed $totalFiles installer files. Found $($packageData.Count) unique packages."
    Write-Host "Filtering for GitHub installer URLs..."
    
    # Filter for GitHub URLs and get latest releases
    $results = @()
    $processedCount = 0
    $totalPackages = $packageData.Count
    
    $progressParams = @{
        Activity        = "Checking GitHub releases"
        Status          = "0" + "/" + "$totalPackages Complete"
        PercentComplete = 0
    }
    
    foreach ($packageId in $packageData.Keys) {
        $processedCount++
        

        $percent = [math]::Min(100, [math]::Round(($processedCount / $totalPackages) * 100))
        $progressParams.Status = "$processedCount" + "/" + "$totalPackages Complete"
        $progressParams.PercentComplete = $percent
        Write-Progress @progressParams

        
        $package = $packageData[$packageId]
        $githubInfo = Get-GitHubInfo -Url $package.InstallerUrl
        
        if ($githubInfo) {
            # Get latest GitHub release
            $latestRelease = Get-LatestGitHubRelease -Owner $githubInfo.Owner -Repo $githubInfo.Repo -Token $GitHubToken
            
            $currentVersion = Get-CleanVersion -Version $package.CurrentVersion
            $latestVersion = Get-CleanVersion -Version $latestRelease
            
            # Calculate relative file path for better readability
            $relativePath = $package.FilePath.Substring($TempDir.Length)
            
            $results += [PSCustomObject]@{
                PackageId      = $packageId
                CurrentVersion = $currentVersion
                LatestVersion  = $latestVersion
                GitHubOwner    = $githubInfo.Owner
                GitHubRepo     = $githubInfo.Repo
                GitHubUrl      = "https://github.com/$($githubInfo.Owner)/$($githubInfo.Repo)"
                InstallerUrl   = $package.InstallerUrl
                ManifestPath   = $relativePath
            }
        }
    }

    # retry if "LatestVersion" is "ratelimit" and update $results
    $retryprocessCount = 0
    $totalPackages = $results.Count
    foreach ($result in $results) {
        $retryprocessCount++
        $percent = [math]::Min(100, [math]::Round(($retryprocessCount / $totalPackages) * 100))
        $progressParams.Status = "$retryprocessCount" + "/" + "$totalPackages Complete"
        $progressParams.PercentComplete = $percent
        Write-Progress @progressParams

        if ($result.LatestVersion -eq "ratelimit") {
            
            $githubInfo = Get-GitHubInfo -Url $result.InstallerUrl
            if ($githubInfo) {
                "checking $($result.PackageId) for latest version..."
                $latestRelease = Get-LatestGitHubRelease -Owner $githubInfo.Owner -Repo $githubInfo.Repo -Token $GitHubToken
                $cleanVersion = Get-CleanVersion -Version $latestRelease

                # Update the LatestVersion property in the $result object
                $result.LatestVersion = $cleanVersion
            }
        }
    }
    Write-Progress -Activity "Checking GitHub releases" -Completed

    # clean Versions and PackageId from " and '
    $results | ForEach-Object {
        $_.CurrentVersion = $_.CurrentVersion -replace '"', '' -replace "'", ''
        $_.LatestVersion = $_.LatestVersion -replace '"', '' -replace "'", ''
        $_.PackageId = $_.PackageId -replace '"', '' -replace "'", ''
    }
    # Find packages with different versions
    $filteredresults = $results | Where-Object { $_.CurrentVersion -ne $_.LatestVersion -and $_.LatestVersion -ne "Unknown" -and $_.LatestVersion -ne "ratelimit" }    
    
    # Export to CSV
    Write-Host "Exporting $($results.Count) packages to CSV: $OutputPath"
    $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    $filteredresults | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "Analysis completed in $($duration.TotalMinutes.ToString('0.00')) minutes."
    Write-Host "Found $($results.Count) packages with GitHub installer URLs."
    Write-Host "Results saved to: $OutputPath"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
finally {
    # Clean up temporary files
    Write-Host "Cleaning up temporary files..."
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}