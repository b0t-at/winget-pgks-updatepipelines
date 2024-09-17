Import-Module Microsoft.WinGet.Client
$ErrorActionPreference = "Stop"
$packages = Import-Csv -Path .\broken_packages.csv
$ignored_packages = Import-Csv -Path .\ignored_packages.csv
$DRY_RUN = $false
$REMOVE_HIGHEST_VERSIONS = $false

$successfullPackages = @()
foreach ($package in $packages) {
    if ($ignored_packages | Where-Object { $_.package_identifier -eq $package.package_identifier -and ($_.package_version -eq "*" -or $_.package_version -eq $package.package_version) }) {
        write-host "Ignoring package $($package.package_identifier) | $($package.package_version)"
        continue
    }

    Write-Host "Checking package $($package.package_identifier) | $($package.package_version)"
    $output = & winget.exe download --id $package.package_identifier --version $package.package_version
    $lastOutputLine = $output | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) {
        if ([string]::Join('`n', $output).Contains($package.http_codes) -or $lastOutputLine.Contains("Hash-Wert")) {
            Write-Host "Package $($package.package_identifier) | $($package.package_version) | Failed to download"
            
            $ExistingPRs = gh pr list --search "Remove version: $($package.package_identifier) version $($package.package_version) in:title draft:false" --state 'all' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
            #$isHighestVersion =  (Find-WinGetPackage --id $package.package_identifier).version -eq $package.package_version
            $isHighestVersion = (& winget.exe search --id $package.package_identifier --exact ) -contains $package.package_version
            
            if($isHighestVersion -eq $true -and $REMOVE_HIGHEST_VERSIONS -eq $false) {
                Write-Host "Ignoring package $($package.package_identifier) | $($package.package_version) as it is the highest version"
                continue
            }
            if($isHighestVersion -and $lastOutputLine.Contains("Hash-Wert")) {
                Write-Host "Ignoring package $($package.package_identifier) | $($package.package_version) as it has hash mismatch and is the highest version"
                continue
            }
            if ($ExistingPRs.Count -gt 0) {
                Write-Output "$foundMessage"
                $ExistingPRs | ForEach-Object {
                    Write-Output "Found existing PR: $($_.title)"
                    Write-Output "-> $($_.url)"
                }
            }
            else {
                Write-Output "No existing PR found for $($package.package_identifier) | $($package.package_version)"
                if ($DRY_RUN -eq $false) {
                    if($lastOutputLine.Contains("Hash-Wert")) {
                        $prBody = "installer has hash mismatch while a new version is available"
                    } else {
                        $prBody = "installers return following HTTP status code: $($package.http_codes)"            
                    }
                    . komac.exe remove --reason $prBody --submit -v $package.package_version  $package.package_identifier 
                }
            }
        }
        else {
            Write-Warning "HTTP status code mismatch for package $($package.package_identifier) | $($package.package_version) | Expected: $($package.http_codes) | Actual: $lastOutputLine"
        }
        continue
    }

    Write-Host "$($package.package_identifier) | $($package.package_version) | Package does not need PR as it is not broken"
    $successfullPackages += $package
}

Write-Host "Successfull Packages: $($successfullPackages | ConvertTo-Json)"
