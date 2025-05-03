function Get-LatestARPVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Tag,
        [Parameter(Mandatory = $false)][object]$ListToTrimFromTag = @("v", "V", "RELEASE_"),
        [Parameter(Mandatory = $true)][string]$GHURLs
    )

    # If the GHURLs contain {ARPVERSION}, find the ARP version from the asset links via regex
    if ($GHURLs -match "{ARPVERSION}") {
        $latestRelease = gh release view --repo $Repo $Tag --json assets | ConvertFrom-Json

        # Build the regex pattern from GHURLs, capturing the ARP version
        $regex = $GHURLs -replace "{ARPVERSION}", "(.+?)" -replace "{TAG}", [Regex]::Escape($Tag)
        
        # Loop through assets and return first captured ARP version from the URL
        foreach ($asset in $latestRelease.assets) {
            if ($asset.url -match $regex) {
                return $matches[1]
            }
        }
        throw "No ARP version found in the assets for tag $Tag in repo $Repo"
    }
    else {
        # Create a regex pattern from all prefixes
        $pattern = "^(" + ($ListToTrimFromTag -join "|") + ")"
        $cleanLatestVersion = $versionTag -replace $pattern, ""
        return $cleanLatestVersion
    }
    
}