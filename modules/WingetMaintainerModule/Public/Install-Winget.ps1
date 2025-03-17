function Install-Winget {
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'silentlyContinue'
    $latestWingetMsixBundleUri = $(Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest).assets.browser_download_url | Where-Object { $_.EndsWith(".msixbundle") }
    $latestWingetMsixBundle = $latestWingetMsixBundleUri.Split("/")[-1]
    Write-Host "Downloading winget..."
    Invoke-WebRequest -Uri $latestWingetMsixBundleUri -OutFile "./$latestWingetMsixBundle"
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage $latestWingetMsixBundle

    start-sleep 20
    $ProgressPreference = $oldProgressPreference
    Write-Host "winget installed successfully"

    Write-Host "Installing winget PowerShell Module"
    Install-Module -Name Microsoft.WinGet.Client -Force -AllowClobber
    Write-Host "winget PowerShell Module installed successfully"

    # https://learn.microsoft.com/en-us/windows/package-manager/winget/#install-winget-on-windows-sandbox
    # Write-Host "Installing WinGet PowerShell module from PSGallery..."
    # #Install-PackageProvider -Name NuGet -Force | Out-Null
    # Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -AllowClobber
    # Write-Host "Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..."
    # Repair-WinGetPackageManager -AllUsers
}