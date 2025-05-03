function Get-LatestGHVersionTag {
    param(
        [Parameter(Mandatory = $true)][string]$Repo
    )


    $latestRelease = gh release list --repo $Repo --json "name,tagName,publishedAt,isLatest,isPrerelease" | ConvertFrom-Json | Where-Object { $_.isPrerelease -eq $false -and $_.isLatest -eq $true } | Sort-Object -Property publishedAt -Descending | Select-Object -First 1
    $latestVersionTag = $latestRelease.tagName

    if ($latestVersionTag) {
        Write-Host "Latest Tag of $Repo : $latestVersionTag"
        return $latestVersionTag
    } 
    else {
        Write-Host "No Tag found for Repo $Repo"
        exit 1
    }
}