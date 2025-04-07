function Get-ProductVersionFromFile {
    param(
        [Parameter(Mandatory = $true)] [string] $WebsiteURL,
        [Parameter(Mandatory = $true)] [string] $VersionInfoProperty
    )

    $latestVersionUrl = $WebsiteURL
    $DownloadFileName = [System.IO.Path]::GetFileName($latestVersionUrl)
    Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName

    $tempDir = $null

    # If the file is a ZIP file, unzip it into a temporary directory and search for .exe or .msi files
    if ($DownloadFileName -like "*.zip") {
        $tempDir = Join-Path -Path $env:TEMP -ChildPath ("winget_extract_" + [Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $tempDir | Out-Null
        Expand-Archive -Path $DownloadFileName -DestinationPath $tempDir
        $file = Get-ChildItem -Path $tempDir -Include "*.exe", "*.msi" -Recurse | Select-Object -First 1
    }
    else {
        $file = Get-ChildItem -Path $DownloadFileName
    }

    if ($null -eq $file) {
        Write-Host "File not found"
        exit 1
    }

    if ($null -eq $file.VersionInfo) {
        Write-Host "No version info found in file"
        exit 1
    }

    $versionInfo = $file.VersionInfo.$VersionInfoProperty
    $versionInfo = $versionInfo.ToString().Trim()

    if ($null -eq $versionInfo) {
        Write-Host "Could not find version info in file"
        exit 1
    }

    # Clean up: delete the downloaded file and extracted folder (if any)
    if (Test-Path $DownloadFileName) {
        Remove-Item -Path $DownloadFileName -Force
    }
    if ($tempDir -and (Test-Path $tempDir)) {
        Remove-Item -Path $tempDir -Recurse -Force
    }

    return $versionInfo
}