$redirectUrl = "https://www.amazon.com/kindlepcdownload"
try {
    Invoke-WebRequest -Method Get -Uri $redirectUrl -MaximumRedirection 0  -ErrorAction Continue 
}
catch {
    if ($_.Exception.Response.StatusCode -eq 301) {
        $RedirectUrl = $_.Exception.Response.Headers.Location
    }
}

if(!$RedirectUrl) {
    throw "Failed to retrieve the redirect URL."
}
KindleForPC-installer-2.7.70978.exe
$latestVersionUrl = $RedirectUrl.AbsoluteUri
$latestVersion = [regex]::Match($RedirectUrl.AbsolutePath, '.*.*KindleForPC-installer-(\d+.\d+.\d+).*').Groups[1].Value

return [PSCustomObject]@{
    Version = $latestVersion
    URLs    = $latestVersionUrl
}