function Install-Komac {
    $executable = Get-Command "komac" -ErrorAction SilentlyContinue
    if ($null -ne $executable) {
        Write-Host "Komac is already installed"
        return
    }


    if (-not (Test-Path ".\komac.exe")) {
        # Get latest release info using GitHub CLI
        $latestRelease = gh release view --repo russellbanks/Komac --json assets | ConvertFrom-Json
    
        # Find the Windows asset
        $windowsAsset = $latestRelease.assets | Where-Object { $_.name.EndsWith("x86_64-pc-windows-msvc.exe") } | Select-Object -First 1
    
        if ($windowsAsset) {
            # Download the asset directly using GitHub CLI
            gh release download --repo russellbanks/Komac --pattern $windowsAsset.name --output komac.exe
            # For nightly builds (commented)
            # gh release download --repo russellbanks/Komac nightly --pattern "*-x86_64-pc-windows-msvc.exe" --output komac.exe
        }
        else {
            Write-Error "Could not find Windows executable in latest Komac release"
            exit 1
        }
    }

    if (Test-Path ".\komac.exe") {
        Write-Host "Komac successfully downloaded"
        New-Alias komac "$(get-location)\komac.exe" -scope Global
    }
    else {
        Write-Error "Komac not downloaded"
        exit 1
    }
}
