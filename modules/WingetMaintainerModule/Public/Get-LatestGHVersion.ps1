function Get-LatestGHVersion {
    param(
        [Parameter(Mandatory = $true)][string]$Repo
    )


    $latestRelease = gh release list --repo $Repo --json "name,tagName,publishedAt,isLatest,isPrerelease" | ConvertFrom-Json | Where-Object { $_.isPrerelease -eq $false -and $_.isLatest -eq $true } | Sort-Object -Property publishedAt -Descending | Select-Object -First 1
    $latestVersionTag = $latestRelease.tagName

    if ($latestVersionTag) {
        Write-Host "Latest Version of $Repo : $latestVersionTag"
        return $latestVersionTag
    } 
    else {
        Write-Host "No Version found for Repo $Repo"
        exit 1
    }
}