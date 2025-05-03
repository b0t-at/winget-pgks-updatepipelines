function Get-GHReleaseNotes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $false)][string]$Version
    )

    # Get the release notes for a specific version or the latest release
    if ($Version) {
        $releaseNotes = gh release view "$Version" --repo $Repo --json "body" | ConvertFrom-Json | Select-Object -ExpandProperty body
    } else {
        $releaseNotes = gh release view --repo $Repo --json "body" | ConvertFrom-Json | Select-Object -ExpandProperty body
    }

    return $releaseNotes
}