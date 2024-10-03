function Get-LatestMongoDBVersions {
    param(
        [Parameter(Mandatory = $true)] [string] $WebsiteURL,
        [Parameter(Mandatory = $true)] [string] $PackageFilter
    )

    $website = Invoke-WebRequest -Uri $WebsiteURL
    $content = $website.Content

    $links = $content | Select-String -Pattern 'https?://[^"]+' -AllMatches | % { $_.Matches } | % { $_.Value }
    $msilinks = $links | Select-String -Pattern 'https?://[^\s]*\.msi' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }

    $Packagelinks = $msilinks | Select-String -Pattern "https?://[^\s]*$PackageFilter[^\s]*\.msi" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Where-Object { $_ -notmatch "$PackageFilter-isolated|$PackageFilter-readonly" }

    $versions = $Packagelinks | ForEach-Object { $_ -match '(\d+\.\d+\.\d+(-rc\d*|-beta\d*)?)' | Out-Null; $matches[1] }
    $stableVersions = $versions | Where-Object { $_ -notmatch '(-rc|beta)' }

    $latestVersion = $stableVersions | Sort-Object { [Version]$_ } | Select-Object -Last 1
    $latestVersionUrl = $Packagelinks | Where-Object { $_ -match $latestVersion }

    return @{
        Version = $latestVersion
        Url     = $latestVersionUrl
    }
}
