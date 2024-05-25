. .\Scripts\common.ps1

Invoke-WebRequest -Method Get -Uri "$WebsiteURL/nuget.exe" -OutFile "nuget.exe"
$fileInfo = Get-Item "nuget.exe"
$fileVersion = $fileInfo.VersionInfo.FileVersion
$packageVersion = $fileVersion -replace '(\d+\.\d+.\d+).*', '$1'

$downloadUrl = "https://dist.nuget.org/win-x86-commandline/v$packageVersion/nuget.exe"

# check if full download URL is valid
$fullDownloadURLResponse = Invoke-WebRequest -Uri $downloadUrl -UseBasicParsing -Method Head
if ($fullDownloadURLResponse.StatusCode -ne 200) {
    Write-Host "Full download URL is not valid"
    exit 1
}

return $packageVersion, $downloadUrl
