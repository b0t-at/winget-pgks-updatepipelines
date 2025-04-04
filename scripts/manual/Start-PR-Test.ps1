# get all open prs of damn-good-b0t in microsoft/winget-pkgs via gh cli
$openPRs = gh pr list --state open --json number,title,state,author --repo "microsoft/winget-pkgs" -A "damn-good-b0t" --limit 9999 | ConvertFrom-Json
$workflow = "test-manifest.yml"
foreach($pr in $openPRs) {
    # trigger github workflow "test-manifest.yml"
    # for each open pr
    $prNumber = $pr.number
    $prTitle = $pr.title
    Write-Host "Triggering workflow for PR #$($prNumber): $prTitle"
    gh workflow run $workflow --field PRNumber=$prNumber
}