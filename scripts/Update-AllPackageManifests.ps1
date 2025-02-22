param(
    [Parameter(Mandatory = $true)] [string] $PackageIdentifier,
    [Parameter(Mandatory = $true)] [string] $OutputDir,
    [Parameter(Mandatory = $true)] [string] $Token,
    [Parameter(Mandatory = $false)] [string] $Submit,
    [Parameter(Mandatory = $false)] [string] $Resolves
)
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDirectory = Split-Path -Parent $scriptPath
Import-Module "$scriptDirectory\..\modules\WingetMaintainerModule"
# Check if powershell-yaml module is installed
if (-not (Get-Module -Name powershell-yaml -ListAvailable)) {
    # Install powershell-yaml module
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force
}

# Import powershell-yaml module
Import-Module -Name powershell-yaml


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
    $versions = (.\komac.exe  list-versions $PackageIdentifier --json -t $Token) | ConvertFrom-Json

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


function Update-AllWingetPackages {
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
    Install-Komac
    foreach ($version in $manifestDict.Keys) {
        $manifest = $manifestDict[$version]
        Write-Host "Processing $PackageIdentifier version $version"
        # Extract the installer links from the manifest
        $installerLinks = Export-InstallerLinks -Manifest $manifest
        # only perform rebuild if it will not be submitted or if no PR exists
        if($Submit -eq $false ? $true : !(Test-ExistingPRs -PackageIdentifier $PackageIdentifier -Version $version -OnlyOpen)) {
        .\komac.exe update $PackageIdentifier --version $version --urls $installerLinks -o $OutputDir -t $Token ($Submit -eq $true ? '-s' : '--dry-run') ($resolves -match '^\d+$' ? "--resolves $resolves" : $null )
        }
    }
}

Update-AllWingetPackages -PackageIdentifier $PackageIdentifier -OutputDir $OutputDir -All





