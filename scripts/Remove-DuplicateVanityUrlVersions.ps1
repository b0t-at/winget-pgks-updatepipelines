param(
    [string]$RepoPath = $Global:WINGET_PKGS_REPO_PATH
)

Import-Module "$PSScriptRoot/../modules/WingetMaintainerModule"

# function Get-ManifestObjects {
#     param([string]$ManifestsRoot)
#     $installerFiles = Get-ChildItem -Path $ManifestsRoot -Recurse -File | Where-Object { $_.Name -match '\.installer\.(yaml|yml)$' }
#     $total = $installerFiles.Count
#     $current = 0
#     foreach ($file in $installerFiles) {
#         $current++
#         Write-Progress -Activity "Lese Manifestdateien" -Status "$current von $total" -PercentComplete (($current / $total) * 100)
#         try {
#             $content = Get-Content -Raw -Path $file.FullName
#             if ($content -match '(?m)^PackageIdentifier\s*:\s*(.+?)$') {
#                 $packageId = $matches[1].Trim()
#             }
#             if ($content -match '(?m)^PackageVersion\s*:\s*(.+?)$') {
#                 $version = $matches[1].Trim()
#             }
#             if ($content -match '(?m)InstallerUrl\s*:\s*(.+?)(\r?\n|\z)') {
#                 $installerUrl = $matches[1].Trim()
#             }
#             if ($packageId -and $version -and $installerUrl) {
#                 [PSCustomObject]@{
#                     PackageId    = $packageId
#                     Version      = $version
#                     InstallerUrl = $installerUrl
#                     ManifestPath = $file.FullName
#                 }
#             }
#         } catch {
#             Write-Warning "Failed to parse $($file.FullName): $_"
#         }
#     }
#     Write-Progress -Activity "Lese Manifestdateien" -Completed
# }

function Get-ManifestObjects {
    param(
        [string]$ManifestsRoot,
        [int]$ThrottleLimit = ([System.Environment]::ProcessorCount) # Number of parallel threads
    )

    # Start a stopwatch to measure execution time (optional)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $installerFiles = Get-ChildItem -Path $ManifestsRoot -Recurse -File | Where-Object { $_.Name -match '\.installer\.(yaml|yml)$' }
    $total = $installerFiles.Count

    if ($total -eq 0) {
        Write-Warning "No installer manifest files found in '$ManifestsRoot'."
        return @()
    }

    # Shared data for progress tracking.
    # We use a synchronized hashtable to make counter updates thread-safe.
    $progressData = [hashtable]::Synchronized(@{ processedCount = 0 })
    
    # Generate a unique ID for this progress bar instance to avoid conflicts
    # if other progress bars are active.
    $progressId = Get-Random 

    # Initial display of the progress bar
    Write-Progress -Id $progressId -Activity "Lese Manifestdateien (Parallel)" -Status "0 von $total verarbeitet" -PercentComplete 0

    $results = $installerFiles | ForEach-Object -Parallel {
        # Inside the parallel script block, $using: allows access to variables
        # from the caller's scope.
        $file = $_
        $parentProgressId = $using:progressId     # The ID for Write-Progress
        $totalFiles = $using:total           # Total number of files
        $sharedProgressData = $using:progressData # The synchronized hashtable

        $packageId = $null
        $version = $null
        $installerUrl = $null
        
        try {
            $content = Get-Content -Raw -Path $file.FullName
            if ($content -match '(?m)^PackageIdentifier\s*:\s*(.+?)$') {
                $packageId = $matches[1].Trim()
            }
            if ($content -match '(?m)^PackageVersion\s*:\s*(.+?)$') {
                $version = $matches[1].Trim()
            }
            # Updated regex to ensure it captures URL correctly even if it's the last line
            if ($content -match '(?m)InstallerUrl\s*:\s*(.+?)(\r?\n|\s*$)') {
                $installerUrl = $matches[1].Trim()
            }

            if ($packageId -and $version -and $installerUrl) {
                [PSCustomObject]@{
                    PackageId    = $packageId
                    Version      = $version
                    InstallerUrl = $installerUrl
                    ManifestPath = $file.FullName
                }
            }
        }
        catch {
            # Output warnings for files that fail to parse. These will appear in the console.
            Write-Warning "Failed to parse $($file.FullName): $($_.Exception.Message)"
        }
        finally {
            # This block executes whether the try block succeeded or failed.
            # Increment the processed files counter and update the progress bar.
            $currentProcessedCount = 0
            # Lock the synchronized hashtable to ensure thread-safe update of the counter.
            $sharedProgressData.processedCount = $sharedProgressData.processedCount + 1
            $currentProcessedCount = $sharedProgressData.processedCount
            
            # Update the progress bar from this parallel task.
            Write-Progress -Id $parentProgressId -Activity "Lese Manifestdateien (Parallel)" -Status "$currentProcessedCount von $totalFiles verarbeitet" -PercentComplete (($currentProcessedCount / $totalFiles) * 100)
        }
    } -ThrottleLimit $ThrottleLimit # Controls how many script blocks run in parallel

    # Mark the progress bar as completed once all items are processed.
    Write-Progress -Id $progressId -Activity "Lese Manifestdateien (Parallel)" -Completed
    
    # Stop the stopwatch and display elapsed time (optional)
    $stopwatch.Stop()
    Write-Verbose "Total time taken for parallel processing: $($stopwatch.Elapsed.TotalSeconds) seconds"

    return $results
}

function Remove-DuplicateVanityUrlVersions {
    param([string]$RepoPath)
    $manifestsPath = Join-Path $RepoPath "manifests"
    $allManifests = Get-ManifestObjects -manifestsPath $manifestsPath

    # Group by PackageId and InstallerUrl
    $groups = $allManifests | Group-Object PackageId, InstallerUrl
    $groupsMultipleVerions = $groups | Where-Object { $_.Count -gt 1 }
    $totalGroups = $groupsMultipleVerions.Count


    $currentGroup = 0

    $ItemsToProceed = @()

    foreach ($group in $groupsMultipleVerions) {
        $currentGroup++
        Write-Progress -Activity "Checking for duplicate versions with same URL" `
            -Status "Processing group $currentGroup of $totalGroups" `
            -PercentComplete (($currentGroup / $totalGroups) * 100)

        $items = $group.Group
        if ($items.Count -gt 1) {
            # Sort versions descending, keep the latest
            #$sorted = $items | Get-STNumericalSorted -InputObject $_.Version -Descending
            $sortedVersion = $items.Version | Get-STNumericalSorted -Descending
            $latestVersion = $sortedVersion | Select-Object -First 1
            $toRemoveVersion = $sortedVersion | Select-Object -Skip 1
            $toRemove = $items | Where-Object { $_.Version -in $toRemoveVersion -and $_.Version -notin $latestVersion }
            foreach ($item in $toRemove) {
                $item | Add-Member -MemberType NoteProperty -Name "latestversion" -Value $latestVersion -Force     
                $packageId = $item.PackageId
                $currentPkgVersionStr = $item.Version
                #$existingPR = Test-ExistingPRs -Version $currentPkgVersionStr -PackageIdentifier $packageId -onlyOpen
                if ($existingPR) {
                    Write-Host "  Existing PR found for $packageId $currentPkgVersionStr. No action needed." -ForegroundColor Green
                    continue
                }
                # check if versions would match if ", ' and trailing .0 are removed
                # $currentPkgVersionStr = $currentPkgVersionStr -replace '"', '' -replace "'", '' -replace '\.0$', ''
                # $latestVersion = $latestVersion -replace '"', '' -replace "'", '' -replace '\.0$', ''
                # $currentPkgVersionStr = $currentPkgVersionStr.replace("'", "").replace("'", "").replace(",","").replace(".0","")
                # $latestVersion = $latestVersion.replace("'", "").replace("'", "").replace(",","").replace(".0","")
                if ($currentPkgVersionStr -eq ($latestVersion -replace 'v', '' -replace 'RELEASE.', '' -replace '"', '' -replace "'", '' -replace '\.0$', '') -or ($currentPkgVersionStr -replace 'v', '' -replace 'RELEASE.', '' -replace '"', '' -replace "'", '' -replace '\.0$', '') -eq $latestVersion) {
                    Write-Host "  Version $currentPkgVersionStr matches latest version $latestVersion. No action needed." -ForegroundColor Green
                    break
                }
                #Write-Host "Removing $($item.PackageId) version $($item.Version) (URL: $($item.InstallerUrl)) - newer version with same URL: $latestVersion" -ForegroundColor Yellow
                $item | Select-Object version, latestversion, InstallerUrl, PackageId 
                $ItemsToProceed += $item
                $reason = "Removing $($item.PackageId) version $($item.Version) (URL: $($item.InstallerUrl)) - newer version with same URL: $latestVersion"
                #komac remove $item.PackageId --version $item.Version --reason "$reason" --submit
            }
        }
    }
    Write-Progress -Activity "Checking for duplicate versions with same URL" -Completed
}

$ItemsToProceedSelected = $ItemsToProceed | out-gridview -OutputMode Multiple



$ItemsToProceedSelected | Where-Object { $_.PackageID -like "*the-sz*" } | ForEach-Object {
    $existingPR = Test-ExistingPRs -Version $_.Version.replace("'", "").replace('"', "") -PackageIdentifier $_.PackageId -onlyOpen
    if ($existingPR) {
        Write-Host "  Existing PR found for $($_.PackageId) $($_.Version). No action needed." -ForegroundColor Green
    }
    else {
        Write-Host "Removing $($_.PackageId) version $($_.Version) (URL: $($_.InstallerUrl)) - newer version with same URL: $($_.latestversion)" -ForegroundColor Yellow
        komac remove $_.PackageId --version $_.Version.replace("'", "").replace('"', "") --reason "Removing $($_.PackageId) version $($_.Version) (URL: $($_.InstallerUrl)) - newer version with same URL: $($_.latestversion)" --submit --token $komactoken
    }
}


Remove-DuplicateVanityUrlVersions -RepoPath $RepoPath