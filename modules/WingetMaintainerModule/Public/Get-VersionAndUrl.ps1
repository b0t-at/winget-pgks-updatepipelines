Function Get-VersionAndUrl {
    param(
        [Parameter(Mandatory = $true)] [string] $wingetPackage,
        [Parameter(Mandatory = $false)] [string] $WebsiteURL
    )

    $scriptPath = ".\scripts\Packages\Update-$($wingetPackage).ps1"

    if (-not (Test-Path -Path $scriptPath)) {
        Write-Host "The script '$scriptPath' does not exist. Please check the wingetPackage parameter and the current directory."
        exit 1
    }
    Write-Host "Running $scriptPath"
    $Latest = & $scriptPath -WebsiteURL $WebsiteURL -wingetPackage $wingetPackage

    ## Check for Release Notes
    $releaseNotesPattern = 'ReleaseNotes:'
    $releaseNotes = $Latest | Where-Object { $_ -match $releaseNotesPattern }

    if (!($Latest | Get-Member -Name "Version") -or !($Latest | Get-Member -Name "URLs")) {

        $lines = $Latest | Where-Object { $_ -notmatch $releaseNotesPattern } -split "`n" -split " "

        $versionPattern = '^\d+(?:\.\d+)*(-(?:alpha|beta)\.?\d+)?$'
        $urlPattern = '^http[s]?:\/\/[^\s]+(\.msi|\.exe|\.appx|\.zip)(\|(x64|x86|x32))?$'

        $version = $lines | Where-Object { $_ -match $versionPattern } | Get-STNumericalSorted -Descending | Select-Object -First 1
        $URLs = $lines | Where-Object { $_ -match $urlPattern }

        if ($version -and $URLs) {
            $Latest = @{
                Version = $version
                URLs    = $URLs.split(",").trim().split(" ")
            }
        }
        else {
            Write-Host "No Version ($version) or URL ($($URLs -join ',')) found."
            exit 1
        }
    }

    if (!($Latest | Get-Member -Name "ReleaseNotes")) {

        if ($releaseNotes) {
            $Latest.Add("ReleaseNotes", $releaseNotes)
            Write-Host "Found Release Notes:"
            Write-Host $releaseNotes
        }
        else {
            Write-Host "ReleaseNotes not found in the content but releaseNotes are not required."
        }
    }

Write-Host "Found latest version: $version with URLs: $($Latest.URLs -join ',')"
return $Latest
}