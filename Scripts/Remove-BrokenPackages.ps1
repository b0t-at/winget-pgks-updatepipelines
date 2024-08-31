$packages = Import-Csv -Path .\broken_package.csv
$successfullPackages = @()
foreach ($package in $packages) {
    $prBody = "installers return following HTTP status code: $($package.http_codes)"
    . winget.exe download --id $package.package_identifier --version $package.package_version

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Package $($package.package_identifier) | $($package.package_version) | Failed to download"
        . komac.exe remove --reason $prBody --submit -v $package.package_version  $package.package_identifier 
        continue
    }

    Write-Host "$($package.package_identifier) | $($package.package_version) | Package does not need PR as it is not broken"
    $successfullPackages += $package
}

Write-Host "Successfull Packages: $($successfullPackages | ConvertTo-Json)"
