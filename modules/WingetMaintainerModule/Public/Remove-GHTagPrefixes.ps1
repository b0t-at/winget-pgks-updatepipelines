function Remove-GHTagPrefixes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Tag,
        [Parameter(Mandatory = $false)][object]$ListToTrimFromTag = @("v", "V", "RELEASE_")
    )
    # Create a regex pattern from all prefixes
    $pattern = "^(" + ($ListToTrimFromTag -join "|") + ")"
    $cleanLatestVersion = $Tag -replace $pattern, ""
    return $cleanLatestVersion

}