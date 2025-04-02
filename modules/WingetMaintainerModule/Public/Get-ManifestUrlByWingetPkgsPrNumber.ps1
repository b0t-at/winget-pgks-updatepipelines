function Get-ManifestUrlByWingetPkgsPrNumber { 
    param(
        [Parameter(Mandatory = $true)] [string] $PRNumber
    )
    # get changed files in the PR through gh cli
    $changedFiles = gh pr view "$PRNumber" --json files --jq '.files[].path' --repo microsoft/winget-pkgs
    $headRefOid = gh pr view "$PRNumber" --json headRefOid --jq '.headRefOid' --repo microsoft/winget-pkgs

    # take first path that starts with "manifests/" and remove filename at the end
    $manifestPath = $changedFiles | Where-Object { $_ -like "manifests/*" } | Select-Object -First 1
    if ($null -eq $manifestPath) {
        Write-Host "No manifest path found"
        exit 1
    }
    # remove filename at the end
    $manifestPath = $manifestPath.Substring(0, $manifestPath.LastIndexOf("/"))

    # build remote url
    $manifestBaseUrl = "https://raw.githubusercontent.com/microsoft/winget-pkgs/$headRefOid/$manifestPath"
    return $manifestBaseUrl
}