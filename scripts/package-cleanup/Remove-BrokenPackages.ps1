Import-Module Microsoft.WinGet.Client
$ErrorActionPreference = "Stop"

$DRY_RUN = $true
$USE_WHITELIST = $false
$REMOVE_HIGHEST_VERSIONS = $false
#$timeoutSeconds = 60  # Set your desired timeout in seconds

# check if Microsoft.WinGet.Client module is installed
if (-not (Get-Module -Name Microsoft.WinGet.Client -ListAvailable)) {
    Write-Host "Microsoft.WinGet.Client module is not installed. Please install it"
}
else {
    Import-Module Microsoft.WinGet.Client
}

# get current script directory
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

if ([string]::IsNullOrEmpty($scriptDirectory)) {
    Write-Host "Failed to get script directory. Falling back to current directory"
    $scriptDirectory = (Get-Location).Path
}

# get files that start with naming "Broken Packages-data-"
$brokenPackagesFiles = Get-ChildItem -Path $scriptDirectory -Filter "Broken Packages-data-*" | Sort-Object -Property LastWriteTime -Descending
if ($brokenPackagesFiles.Count -eq 0) {
    Write-Host "No broken packages data file found"
    exit 1
}
if ($brokenPackagesFiles.Count -gt 1) {
    Write-Warning "Multiple broken packages data files files found. Aborting"
    exit 1
}
$brokenPackageFileAbsolutePath = $brokenPackagesFiles[0].FullName

$packages = Import-Csv -Path $brokenPackageFileAbsolutePath
$ignored_packages = Import-Csv -Path $scriptDirectory\ignored_packages.csv
$whitelist_packages = Import-Csv -Path $scriptDirectory\whitelist_packages.csv

$whitelistDict = @{}
foreach ($whitelist in $whitelist_packages) {
    $whitelistDict[$whitelist.package_identifier] = $whitelist.package_identifier
}

# filter out packages that are not in whitelist
if($USE_WHITELIST -eq $true) {
    $packages = $packages | Where-Object { $whitelistDict.ContainsKey($_.package_identifier) }
}

$successfullPackages = @()
#$timeoutPackages = @()
foreach ($package in $packages) {
    if ($ignored_packages | Where-Object { $package.package_identifier -like $_.package_identifier -and ($_.package_version -eq "*" -or $_.package_version -eq $package.package_version) }) {
        write-host "Ignoring package $($package.package_identifier) | $($package.package_version)"
        continue
    }
    # check if it is already in cleaned_packages.csv
    # test if cleaned_packages.csv exists. create otherwise
    if (-not (Test-Path -Path $scriptDirectory\cleaned_packages.csv)) {
        New-Item -Path $scriptDirectory\cleaned_packages.csv -ItemType File | Out-Null
    }
    if (-not (Test-Path -Path $scriptDirectory\packages_to_remove.csv)) {
        New-Item -Path $scriptDirectory\packages_to_remove.csv -ItemType File | Out-Null
    }
    $cleanedPackages = Import-Csv -Path $scriptDirectory\cleaned_packages.csv
    if ($cleanedPackages | Where-Object { $_.package_identifier -eq $package.package_identifier -and $_.package_version -eq $package.package_version }) {
        Write-Host "Ignoring package $($package.package_identifier) | $($package.package_version) as it is already cleaned"
        continue
    }

    Write-Host "Checking package $($package.package_identifier) | $($package.package_version)"
    $output = & winget.exe download --id $package.package_identifier --version $package.package_version

    # $process = Start-Process -FilePath "winget.exe" -ArgumentList "download --id $($package.package_identifier) --version $($package.package_version)" -NoNewWindow -PassThru
    # if ($process.WaitForExit($timeoutSeconds * 1000)) {
    #     $output = $process.StandardOutput.ReadToEnd()
    #     $exitCode = $process.ExitCode
    # }
    # else {
    #     $process.Kill()
    #     Write-Warning "The download command timed out after $timeoutSeconds seconds for package $($package.package_identifier) | $($package.package_version)"
    #     $exitCode = -1
    #     $output = ""
    #     $timeoutPackages += $package
    #     continue
    # }

    $lastOutputLine = $output | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) {
        if ([string]::Join('`n', $output).Contains($package.http_codes) -or $lastOutputLine.Contains("Hash-Wert")) {
            Write-Host "Package $($package.package_identifier) | $($package.package_version) | Failed to download"
            
            $ExistingPRs = gh pr list --search "Remove version: $($package.package_identifier) version $($package.package_version) in:title draft:false" --state 'all' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
            $isHighestVersion = ((Find-WinGetPackage -Id $package.package_identifier) | Where-Object { $_.Version -eq $package.package_version -and $_.Id -eq $package.package_identifier }).Count -gt 0
            
            if ($isHighestVersion -eq $true -and $REMOVE_HIGHEST_VERSIONS -eq $false) {
                Write-Host "Ignoring package $($package.package_identifier) | $($package.package_version) as it is the highest version"
                continue
            }
            if ($isHighestVersion -and $lastOutputLine.Contains("Hash-Wert")) {
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
                    if ($lastOutputLine.Contains("Hash-Wert")) {
                        $prBody = "installer has hash mismatch while a new version is available"
                    }
                    else {
                        $prBody = "installers return following HTTP status code: $($package.http_codes)"            
                    }
                    . komac.exe remove --reason $prBody --submit -v $package.package_version  $package.package_identifier 
                    # add it to cleaned_packages.csv
                    $package | Export-Csv -Path $scriptDirectory\cleaned_packages.csv -Append -NoTypeInformation
                } else {
                    # add to packages_to_remove.csv
                    $package | Export-Csv -Path $scriptDirectory\packages_to_remove.csv -Append -NoTypeInformation
                }
            }
        }
        else {
            Write-Warning "HTTP status code mismatch for package $($package.package_identifier) | $($package.package_version) | Expected: $($package.http_codes) | Actual: $lastOutputLine"
        }
        continue
    }

    Write-Warning "$($package.package_identifier) | $($package.package_version) | Package does not need PR as it is not broken"
    $successfullPackages += $package
}

Write-Host "Successfull Packages: $($successfullPackages | ConvertTo-Json)"
#Write-Host "Timeout Packages: $($timeoutPackages | ConvertTo-Json)"
