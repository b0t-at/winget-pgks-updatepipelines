function Get-LatestARPVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $true)][string]$GHURLs
    )
    $splittedGHURLs = $GHURLs.split(" ")
    # If the GHURLs contain {ARPVERSION}, find the ARP version from the asset links via regex
    if ( $splittedGHURLs -match "{ARPVERSION}") {
        $latestRelease = gh release view --repo $Repo $Tag --json assets | ConvertFrom-Json

        # Build the regex pattern from GHURLs, capturing the ARP version
        $regexURLS = $splittedGHURLs -replace "{ARPVERSION}", "(.+?)" -replace "{TAG}", [Regex]::Escape($Tag)
        
        # Loop through assets and return first captured ARP version from the URL
        foreach ($asset in $latestRelease.assets) {
            foreach ($regex in $regexURLS) {
                if ($asset.url -match $regex) {
                    return $matches[1]
                }
            }
        }
        throw "No ARP version found in the assets for tag $Tag in repo $Repo"
    }
    else {
        $cleanLatestVersion = Remove-GHTagPrefixes $Tag
        return $cleanLatestVersion
    }
    
}