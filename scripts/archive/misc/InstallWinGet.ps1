###
###   Unused ATM but might switch back to own solution in the future
###
###     Example:
###
###      - name: Install WinGet
###        run: .\scripts\InstallWinGet.ps1
###        working-directory: Utesgui
###        shell: powershell
###

$ProgressPreference = 'SilentlyContinue'

$VCLibsUri = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
$UILibsUri = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx'
# Timeout for the winget command to become available after installation
$wingetAfterInstallTimeout = 90

$VCLibsPath = New-TemporaryFile
Write-Host "Downloading ${VCLibsUri}"
Invoke-WebRequest -Uri $VCLibsUri -OutFile $VCLibsPath

$UILibsPath = New-TemporaryFile
Write-Host "Downloading ${UILibsUri}"
Invoke-WebRequest -Uri $UILibsUri -OutFile $UILibsPath

$Params = @{
  Uri         = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
  Headers     = @{ Accept = 'application/vnd.github+json' }
  ContentType = 'application/json'
}
if ($Env:GITHUB_TOKEN) {
  Write-Host 'GITHUB_TOKEN detected'
  $Params.Headers['Authorization'] = "Bearer ${Env:GITHUB_TOKEN}"
}
$WinGetRelease = Invoke-RestMethod @Params

$WinGetUri = $WinGetRelease.assets.Where({ $_.name.EndsWith('.msixbundle') })[0].browser_download_url
$WinGetPath = New-TemporaryFile
Write-Host "Downloading ${WinGetUri}"
Invoke-WebRequest -Uri $WinGetUri -OutFile $WinGetPath

$WinGetLicenseUri = $WinGetRelease.assets.Where({ $_.name.EndsWith('_License1.xml') })[0].browser_download_url
$WinGetLicensePath = New-TemporaryFile
Write-Host "Downloading ${WinGetLicenseUri}"
Invoke-WebRequest -Uri $WinGetLicenseUri -OutFile $WinGetLicensePath

Write-Host 'Installing WinGet'
Add-AppxProvisionedPackage -Online -PackagePath $WinGetPath -DependencyPackagePath $VCLibsPath, $UILibsPath -LicensePath $WinGetLicensePath | Out-Null

Write-Host 'Cleaning environment'
Remove-Item -Path @($VCLibsPath, $UILibsPath, $WinGetPath, $WinGetLicensePath) -Force

Write-Host 'Waiting to ensure Winget is ready'
$startTime = Get-Date
$successfullInstall = $false
while ((Get-Date) -lt ($startTime).AddSeconds($wingetAfterInstallTimeout)) {
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host 'Winget successfully installed'
    $successfullInstall = $true
    break
  }
  Start-Sleep -Seconds 5
}
if (-not $successfullInstall) {
  Write-Error 'Winget could not be installed'
  exit 1
}