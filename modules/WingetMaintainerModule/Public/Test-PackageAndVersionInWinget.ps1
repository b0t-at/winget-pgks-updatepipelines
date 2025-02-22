function Test-PackageAndVersionInWinget {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )
    Write-Host "Checking if $wingetPackage is already in winget and Version $($Latest.Version) already present"
    Install-Winget
    $foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

    if (!$wingetVersions) {
        Write-Host "Package not yet in winget. Please add new package manually"
        exit 1
    } 
    elseif ($wingetVersions.contains($latestVersion)) {
        Write-Host "Latest version of $wingetPackage $latestVersion is already present in winget."
        exit 0
    }
    else {
        return $true
    }
}
