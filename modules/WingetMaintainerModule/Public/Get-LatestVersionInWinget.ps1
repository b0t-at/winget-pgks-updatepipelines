function Get-LatestVersionInWinget {
    param(
        [Parameter(Mandatory = $true)] [string] $PackageId
    )

    $packagePath = $PackageId -replace '\.', '/'
    $firstChar = $PackageId[0].ToString().ToLower()

    Write-Host "Checking if $PackageId is already in winget (via GH) and find latest Version"
    
    $ghVersionSearchString = "manifests/$($firstChar)/$($packagePath)/"
    $ghResponse = gh search code $ghVersionSearchString $PackageId".yaml" --match path --repo microsoft/winget-pkgs -L 1000 --json path | ConvertFrom-Json
    $versions = $ghResponse.path | ForEach-Object { $_ -replace ".*$ghVersionSearchString", "" -replace "/.*", "" } | Sort-Object -Descending -Unique
    $sortedVersions = ($versions).TrimStart("v") | Get-STNumericalSorted -Descending
    $latestVersion = $sortedVersions | Select-Object -First 1

    if ($latestVersion) {
        Write-Host "Latest Version of $PackageId in Winget: $latestVersion"
        return $latestVersion
    } 
    else {
        Write-Host "No Version found for Package $PackageId"
        exit 1
    }
}