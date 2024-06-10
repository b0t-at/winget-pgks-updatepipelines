param(
    [Parameter(Mandatory = $true)] [string] $PackageIdentifier,
    [Parameter(Mandatory = $true)] [string] $OutputDir,
    [Parameter(Mandatory = $true)] [string] $Token,
    [Parameter(Mandatory = $false)] [string] $Message
)

# Check if powershell-yaml module is installed
if (-not (Get-Module -Name powershell-yaml -ListAvailable)) {
    # Install powershell-yaml module
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force
}

# Import powershell-yaml module
Import-Module -Name powershell-yaml
. .\Scripts\common.ps1

function Get-InstallerManifestContentGH {
    param(
        [Parameter(Mandatory = $true)] [string] $PackageIdentifier,
        [Parameter(Mandatory = $false)] [string] $Version
    ) 
    $ghInstallerManifestURL = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$($PackageIdentifier.Substring(0, 1).ToLower())/$($PackageIdentifier.replace(".","/"))/$Version/$PackageIdentifier.installer.yaml"
    return Invoke-RestMethod -Uri $ghInstallerManifestURL
}


function Get-AllInstallerManifestsGH {
    param(
        [Parameter(Mandatory = $true)] [string] $PackageIdentifier
    )
    Install-Komac
    $versions = (.\komac.exe  list-versions --identifier $PackageIdentifier --json -t $Token) | ConvertFrom-Json

    $manifestDict = @{}
    foreach ($version in $versions) {
        $manifestDict.Add($version, (Get-InstallerManifestContentGH -PackageIdentifier $PackageIdentifier -Version $version))
    }
    return $manifestDict
}

function Export-InstallerLinks {
    param(
        [Parameter(Mandatory = $true)] [string] $Manifest
    )

    # Load the manifest file as a PowerShell custom object
    $manifestPS = ConvertFrom-Yaml $Manifest

    $installerLinks = @()

    foreach ($installer in $manifestPS.Installers) {
        $installerLinks += $installer.InstallerUrl
    }

    return $installerLinks
}


function Update-WingetPackage {
    param(
        [Parameter(Mandatory = $true)] [string] $PackageIdentifier,
        [Parameter(Mandatory = $true)] [string] $OutputDir,
        [Parameter(Mandatory = $false)] [string] $Version,
        [Parameter(Mandatory = $false)] [switch] $All
    )

    # Get the manifest(s)
    if ($All -eq $true) {
        $manifestDict = Get-AllInstallerManifestsGH -PackageIdentifier $PackageIdentifier
      
    }
    else {
        $manifestDict = @{}
        $manifestDict[$Version] = Get-InstallerManifestContentGH -PackageIdentifier $PackageIdentifier -Version $Version
    }

    foreach ($version in $manifestDict.Keys) {
        $manifest = $manifestDict[$version]
        # Extract the installer links from the manifest
        $installerLinks = Export-InstallerLinks -Manifest $manifest

        Install-Komac
        .\komac.exe update --version $version --identifier  $PackageIdentifier --urls "$($installerLinks -join ' ')" -o $OutputDir -t $Token --dry-run
        }
}

Update-WingetPackage -PackageIdentifier $PackageIdentifier -OutputDir $OutputDir -All





