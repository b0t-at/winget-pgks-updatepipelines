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

    $Latest = Test-LatestMembers -latestObject $Latest

    Write-Host "Found latest version: $($Latest.Version) with URLs: $($Latest.URLs -join ',')"
    return $Latest
}