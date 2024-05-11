. .\Scripts\common.ps1

$latestVersionUrl = $WebsiteURL
$DownloadFileName = "storage-executive-win-64.zip"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName

# Unzip the downloaded file
$UnzipPath = "."
Expand-Archive -Path $DownloadFileName -DestinationPath $UnzipPath

$file = Get-ChildItem -Path . -Filter "*.exe"
$versionInfo = $file.VersionInfo.ProductVersion

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

return "$latestVersionUrl|x64", $versionInfo
