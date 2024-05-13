param(
    [Parameter(Mandatory = $true)] [string] $PackageIdentifier,
    [Parameter(Mandatory = $true)] [string] $OutputDir
)

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
    $versions = (komac.exe  list-versions --identifier $PackageIdentifier --json) | ConvertFrom-Json

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

    $packageFolder = "$OutputDir\manifests\$($PackageIdentifier.Substring(0, 1).ToLower())/$($PackageIdentifier.replace(".", "/"))"
    Set-Location $packageFolder
    git checkout master

    foreach ($version in $manifestDict.Keys) {
        $manifest = $manifestDict[$version]
        # Extract the installer links from the manifest
        $installerLinks = Export-InstallerLinks -Manifest $manifest

        # Create the branch name
        $branchName = "manual_" + $PackageIdentifier + "_" + $version
        # Create a new branch on the remote
        git checkout -b $branchName

        Komac.exe update --version $version --identifier  $PackageIdentifier --urls ($installerLinks -join ' ') -o $OutputDir

        git add $version
        # Commit the changes
        git commit -am "Update existing $PackageIdentifier version $($directory.Name) Manifest"
        git checkout master

        # Push the branch to the remote
        git push origin $branchName
    }

}

#Update-WingetPackage -PackageIdentifier "hoppscotch.Hoppscotch" -OutputDir "C:\Programming\winget-pkgs" -All
Update-WingetPackage -PackageIdentifier $PackageIdentifier -OutputDir $OutputDir -All





