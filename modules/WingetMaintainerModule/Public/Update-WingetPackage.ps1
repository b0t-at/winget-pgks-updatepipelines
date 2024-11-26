function Update-WingetPackage {
    param(
        [Parameter(Mandatory = $false)] [string] $WebsiteURL,
        [Parameter(Mandatory = $false)] [string] $WingetPackage = ${Env:PackageName},
        [Parameter(Mandatory = $false)][ValidateSet("Komac", "WinGetCreate")] [string] $With = "Komac",
        [Parameter(Mandatory = $false)] [string] $resolves = (${Env:resolves} -match '^\d+$' ? ${Env:resolves} : ""),
        [Parameter(Mandatory = $false)] [bool] $Submit = $false,
        [Parameter(Mandatory = $false)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $latestVersionURL,
        [Parameter(Mandatory = $false)] [bool] $IsTemplateUpdate = $false,
        [Parameter(Mandatory = $false)] [string] $releaseNotes
    )

    # Custom validation
    if (-not $IsTemplateUpdate -and -not $WebsiteURL -and (-not $latestVersion -or -not $latestVersionURL)) {
        throw "Either WebsiteURL or both latestVersion and latestVersionURL are required."
    }

    # if ($Submit -eq $false) {
    #     $env:DRY_RUN = $true
    # }


    $gitToken = Test-GitHubToken

    if ($latestVersion -and $latestVersionURL) {
        $Latest = @{
            Version = $latestVersion
            URLs    = $latestVersionURL.split(",").trim().split(" ")
            ReleaseNotes = $releaseNotes
        }
    }
    else {
        Write-Host "Getting latest version and URL for $wingetPackage from $WebsiteURL"
        $Latest = Get-VersionAndUrl -wingetPackage $wingetPackage -WebsiteURL $WebsiteURL
        if ($Latest.ReleaseNotes) {
            $releaseNotes = $Latest.ReleaseNotes
        }
    }

    if ($null -eq $Latest) {
        Write-Host "No version info found"
        exit 1
    }
    Write-Host $Latest
    Write-Host $($Latest.Version)
    Write-Host $($Latest.URLs)
    Write-Host $($Latest.releaseNotes)

    $prMessage = "Update version: $wingetPackage version $($Latest.Version)"

    $PackageAndVersionInWinget = Test-PackageAndVersionInGithub -wingetPackage $wingetPackage -latestVersion $($Latest.Version)

    $ManifestOutPath = "./"

    if ($PackageAndVersionInWinget) {

        $PRExists = Test-ExistingPRs -PackageIdentifier $wingetPackage -Version $($Latest.Version)
        
        if (!$PRExists) {
            Write-Host "Downloading $With and open PR for $wingetPackage Version $($Latest.Version)"
            Switch ($With) {
                "Komac" {
                    Install-Komac
                    .\komac.exe update $wingetPackage --version $Latest.Version --urls ($Latest.URLs).split(" ") --dry-run ($resolves -match '^\d+$' ? "--resolves" : $null ) ($resolves -match '^\d+$' ? $resolves : $null ) -t $gitToken --output "$ManifestOutPath"
                    #.\komac.exe update $wingetPackage --version $Latest.Version --urls ($Latest.URLs).split(" ") ($Submit -eq $true ? '-s' : '--dry-run') ($resolves -match '^\d+$' ? "--resolves" : $null ) ($resolves -match '^\d+$' ? $resolves : $null ) -t $gitToken --output "$ManifestOutPath"
                }
                "WinGetCreate" {
                    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
                    if (Test-Path ".\wingetcreate.exe") {
                        Write-Host "wingetcreate successfully downloaded"
                    }
                    else {
                        Write-Error "wingetcreate not downloaded"
                        exit 1
                    }
                    .\wingetcreate.exe update $wingetPackage -v $Latest.Version -u ($Latest.URLs).split(" ") --prtitle $prMessage -t $gitToken -o $ManifestOutPath

                    #.\wingetcreate.exe update $wingetPackage ($Submit -eq $true ? "-s" : $null ) -v $Latest.Version -u ($Latest.URLs).split(" ") --prtitle $prMessage -t $gitToken -o $ManifestOutPath
                }
                default { 
                    Write-Error "Invalid value \"$With\" for -With parameter. Valid values are 'Komac' and 'WinGetCreate'"
                }
            }

            if ($releaseNotes) {
                $localFiles = Get-ChildItem -Path $ManifestOutPath -Filter "*.local.yml"
                foreach ($file in $localFiles) {
                    Add-Content -Path $file.FullName -Value "`n`n$releaseNotes"
                    $newFile = get-content -path $file.FullName
                    write-Host $newFile
                }
            }

            if ($Submit -eq $true) {
                Write-Host "Submitting PR for $wingetPackage Version $($Latest.Version)"
                wingetcreate.exe submit --prtitle $prMessage -t $gitToken $ManifestOutPath
            }
        }
    }
}
