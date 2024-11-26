function Install-WingetCreate {
    if (-not (Test-Path ".\wingetcreate.exe")) {
        Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    }
    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    if (Test-Path ".\wingetcreate.exe") {
        Write-Host "wingetcreate successfully downloaded"
    }
    else {
        Write-Error "wingetcreate not downloaded"
        exit 1
    }
}
