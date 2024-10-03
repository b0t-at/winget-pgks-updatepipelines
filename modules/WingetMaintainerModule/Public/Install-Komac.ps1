function Install-Komac {
    if (-not (Test-Path ".\komac.exe")) {
        $latestKomacRelease = (Invoke-RestMethod -Uri "https://api.github.com/repos/russellbanks/Komac/releases/latest").assets | Where-Object { $_.browser_download_url.EndsWith("x86_64-pc-windows-msvc.exe") } | Select-Object -First 1 -ExpandProperty browser_download_url
        #$latestKomacRelease = "https://github.com/b0t-at/Komac/releases/download/v2.99/KomacPortable-x64.exe"
        Invoke-WebRequest  -Uri $latestKomacRelease -OutFile komac.exe
    }

    if (Test-Path ".\komac.exe") {
        Write-Host "Komac successfully downloaded"
    }
    else {
        Write-Error "Komac not downloaded"
        exit 1
    }
}
