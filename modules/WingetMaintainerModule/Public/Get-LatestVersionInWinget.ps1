function Get-LatestVersionInWinget {
    param(
        [Parameter(Mandatory = $false)] [string] $PackageId = ${Env:PackageName}
    )
    $packagePath = $PackageId -replace '\.', '/'
    $firstChar = $PackageId[0].ToString().ToLower()
    Write-Host "Checking if $wingetPackage is already in winget (via GH) and find latest Version"
    $ghVersionSearchString = "manifests/$($firstChar)/$($packagePath)/"
    $ghResponse = gh search code $ghVersionSearchString --match path --repo microsoft/winget-pkgs -L 1000 --json path | ConvertFrom-Json
    $versions = $ghResponse.path | Where-Object { $_ -like "*$ghVersionSearchString*" } | ForEach-Object { $_ -replace ".*$ghVersionSearchString", "" } | Sort-Object -Descending
    $uniqueVersions = $versions | ForEach-Object { $_ -replace "/.*", "" } | Sort-Object -Unique
    $sortedVersions = $uniqueVersions | Get-STNumericalSorted -Descending
    $latestVersion = $sortedVersions | Select-Object -First 1

    if ($latestVersion) {
        Write-Host "Latest Version of $PackageId in Winget: $latestVersion"
        return $latestVersion
    } 
    else {
        Write-Host "No Version found for Package $wingetPackage"
        exit 1
    }

}