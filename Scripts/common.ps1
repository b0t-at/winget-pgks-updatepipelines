function Test-GitHubToken {
    if ($Env:GITHUB_TOKEN) {
        Write-Host 'GITHUB_TOKEN detected'
        return ${Env:GITHUB_TOKEN}
    }
    else {
        Write-Host 'GITHUB_TOKEN not detected'
        exit 1
    }
}


function Test-PackageAndVersionInGithub {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )

    $ghVersionURL = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/$latestVersion/$wingetPackage.yaml"
    $ghCheckURL = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/"

    $ghCheck = Invoke-WebRequest -Uri $ghCheckURL -Method Head -SkipHttpErrorCheck 
    if ($ghCheck.StatusCode -eq 404) {
        Write-Output "Packet not yet in winget. Please add new Packet manually"
        exit 1
    } 

    $ghVersionCheck = Invoke-WebRequest -Uri $ghVersionURL -Method Head -SkipHttpErrorCheck
    if ($ghVersionCheck.StatusCode -eq 200) {
        Write-Output "Latest version of $wingetPackage $latestVersion is already present in winget."
        exit 0
    }

    return true
}

function Test-PackageAndVersionInWinget {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )

    $progressPreference = 'silentlyContinue'
    $latestWingetMsixBundleUri = $(Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest).assets.browser_download_url | Where-Object { $_.EndsWith(".msixbundle") }
    $latestWingetMsixBundle = $latestWingetMsixBundleUri.Split("/")[-1]
    Write-Information "Downloading winget to artifacts directory..."
    Invoke-WebRequest -Uri $latestWingetMsixBundleUri -OutFile "./$latestWingetMsixBundle"
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage $latestWingetMsixBundle

    start-sleep 20

    $foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

    if (!$wingetVersions) {
        Write-Output "Packet not yet in winget. Please add new Packet manually"
        exit 1
    } 
    if ($wingetVersions.contains($latestVersion)) {
        Write-Output "Latest version of $wingetPackage $latestVersion is already present in winget."
        exit 0
    }

    return $foundMessage, $wingetVersions
}

function Test-ExistingPRs {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )

    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingPRs = @($ExistingOpenPRs) + @($ExistingMergedPRs)    

    if ($ExistingPRs.Count -gt 0) {
        Write-Output "$foundMessage"
        $ExistingPRs | ForEach-Object {
            Write-Output "Found existing PR: $($_.title)"
            Write-Output "-> $($_.url)"
            exit 0
        }
    }
    else {
        return true
    }
}

function Update-WingetPackage {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $true)] [string] $latestVersionUrls,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName},
        [Parameter(Mandatory = $false)] [ValidateSet("Komac", "WinGetCreate")] [string] $with = "Komac",
        [Parameter(Mandatory = $false)] [string] $gitToken
    )
    if ($null -eq $gitToken) {
        $gitToken = Test-GitHubToken
    }

    $prMessage = "Update version: $wingetPackage version $latestVersion"

    if (Test-PackageAndVersionInGithub -wingetPackage $wingetPackage -latestVersion $latestVersion) {

        if (Test-ExistingPRs -wingetPackage $wingetPackage -latestVersion $latestVersion) {
            Write-Output "Downloading wingetcreate and open PR for $wingetPackage Version $latestVersion"
            Switch ($with) {
                "Komac" {
                    Invoke-WebRequest "https://github.com/russellbanks/Komac/releases/download/v2.2.1/KomacPortable-x64.exe" -OutFile komac.exe
                    .\komac.exe update --identifier $wingetPackage --version $latestVersion --urls "$($latestVersionUrls.replace(' ','" "'))" -s -t $gitToken
                }
                "WinGetCreate" {
                    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
                    .\wingetcreate.exe update $wingetPackage -s -v $latestVersion -u "$($latestVersionUrls.replace(' ','" "'))" --prtitle $prMessage -t $gitToken
                }
            }
        }
    }
}

function Get-VersionAndUrl {
    param(
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName},
        [Parameter(Mandatory = $false)] [string] $VersionInfoURL
    )

    $Latest = .\Update-$($wingetPackage).ps1 -VersionInfoURL $VersionInfoURL -wingetPackage $wingetPackage

    if (!($Latest | Get-Member -Name "Version") -and ($Latest | Get-Member -Name "URLs")) {

        $lines = $Latest -split "`n"

        $versionPattern = '^\d+(\.\d+)*$'
        $urlPattern = '^http[s]?:\/\/[^\s]+$'

        $version = $lines | Where-Object { $_ -match $versionPattern }
        $URLs = $lines | Where-Object { $_ -match $urlPattern }

        if ($version -and $URLs) {
            $Latest = @{
                Version = $version
                URLs    = $URLs
            }
        }
        else {
            Write-Host "No Version ($version) or URL ($($URLs -join ',') found."
            exit 1
        }
    }

    Write-Host "Found latest version: $versionInfo with URLs: $($Latest.URLs -join ',')"
    return $Latest
}

function Start-Update {
    $wingetPackage = ${Env:PackageName}
    $url = ${Env:WebsiteURL}
    $Latest = Get-VersionAndUrl -wingetPackage $wingetPackage -url $url

    Update-WingetPackage -wingetPackage $wingetPackage -latestVersion $Latest.version -with Komac -latestVersionUrls $Latest.URLs
}



$wingetPackage = ${Env:PackageName}
$url = ${Env:WebsiteURL}