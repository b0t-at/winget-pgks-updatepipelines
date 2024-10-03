function Test-GitHubToken {
    if ($Env:GITHUB_TOKEN) {
        Write-Host 'GITHUB_TOKEN detected'
        return ${Env:GITHUB_TOKEN}
    }
    else {
        Write-Host 'GITHUB_TOKEN not detected'
        exit 1
    }
}