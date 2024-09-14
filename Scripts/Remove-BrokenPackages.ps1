$packages = Import-Csv -Path .\broken_package.csv
$DRY_RUN = $false

$successfullPackages = @()
foreach ($package in $packages) {
    $prBody = "installers return following HTTP status code: $($package.http_codes)"
    $output = & winget.exe download --id $package.package_identifier --version $package.package_version

    if ($LASTEXITCODE -ne 0) {
        if([string]::Join('`n',$output).Contains($package.http_codes)) {
            Write-Host "Package $($package.package_identifier) | $($package.package_version) | Failed to download"
            
            $ExistingPRs = gh pr list --search "Remove version: $($package.package_identifier) version $($package.package_version) in:title draft:false" --state 'all' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
            if ($ExistingPRs.Count -gt 0) {
                Write-Output "$foundMessage"
                $ExistingPRs | ForEach-Object {
                    Write-Output "Found existing PR: $($_.title)"
                    Write-Output "-> $($_.url)"
                }
            }
            else {
                Write-Output "No existing PR found for $($package.package_identifier) | $($package.package_version)"
                if($DRY_RUN -eq $false) {
                    . komac.exe remove --reason $prBody --submit -v $package.package_version  $package.package_identifier        
                    }
            }
        } else {
            Write-Warning "HTTP status code mismatch for package $($package.package_identifier) | $($package.package_version)"
        }
        continue
    }

    Write-Host "$($package.package_identifier) | $($package.package_version) | Package does not need PR as it is not broken"
    $successfullPackages += $package
}

Write-Host "Successfull Packages: $($successfullPackages | ConvertTo-Json)"
