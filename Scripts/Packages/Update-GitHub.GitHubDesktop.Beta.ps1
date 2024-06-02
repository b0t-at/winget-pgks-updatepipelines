. .\Scripts\common.ps1

try {
  Invoke-WebRequest -Method Get -Uri $WebsiteURL -MaximumRedirection 0  -ErrorAction Stop 
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        $RedirectUrl = $_.Exception.Response.Headers.Location
        Write-Host $RedirectUrl
    }
    Write-Host $_.Exception.Message
}

$latestVersionUrl = $RedirectUrl.AbsoluteUri
$latestVersion = [regex]::Match($RedirectUrl.AbsolutePath, '.*releases/(\d+.\d+.\d+-\w+)-\w+/.*').Groups[1].Value

return $latestVersion, "$latestVersionUrl"