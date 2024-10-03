function Get-ProductVersionFromFile {
    param(
        [Parameter(Mandatory = $true)] [string] $WebsiteURL,
        [Parameter(Mandatory = $true)] [string] $VersionInfoProperty
    )

    $latestVersionUrl = $WebsiteURL
    $DownloadFileName = [System.IO.Path]::GetFileName($latestVersionUrl)
    Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName

    # If the file is a ZIP file, unzip it and search for .exe or .msi files
    if ($DownloadFileName -like "*.zip") {
        $UnzipPath = "."
        Expand-Archive -Path $DownloadFileName -DestinationPath $UnzipPath
        $file = Get-ChildItem -Path $UnzipPath -Include "*.exe", "*.msi" -Recurse | Select-Object -First 1
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

    return $versionInfo
}