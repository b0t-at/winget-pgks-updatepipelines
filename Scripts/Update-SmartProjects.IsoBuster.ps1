. .\common.ps1

$latestVersionUrl = $WebsiteURL -split " " | Select-Object -First 1
$DownloadFileName = "IsoBuster_installer.exe"
Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName
$file = Get-ChildItem -Path $DownloadFileName
$versionInfo = $file.VersionInfo.ProductVersion.trim()

if ($null -eq $versionInfo) {
    Write-Host "Could not find version info in file"
    exit 1
}

return $versionInfo, $latestVersionUrl
