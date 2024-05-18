function Test-GitHubToken {
    if ($Env:GITHUB_TOKEN) {
        Write-Host 'GITHUB_TOKEN detected'
        return ${Env:GITHUB_TOKEN}
    }
    else {
        Write-Host 'GITHUB_TOKEN not detected'
        exit 1
    }
}


function Test-PackageAndVersionInGithub {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )
    Write-Host "Checking if $wingetPackage is already in winget (via GH) and Version $($Latest.Version) already present"
    $ghVersionURL = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/$latestVersion/$wingetPackage.yaml"
    $ghCheckURL = "https://github.com/microsoft/winget-pkgs/blob/master/manifests/$($wingetPackage.Substring(0, 1).ToLower())/$($wingetPackage.replace(".","/"))/"

    $ghCheck = Invoke-WebRequest -Uri $ghCheckURL -Method Head -SkipHttpErrorCheck 
    $ghVersionCheck = Invoke-WebRequest -Uri $ghVersionURL -Method Head -SkipHttpErrorCheck

    if ($ghCheck.StatusCode -eq 404) {
        Write-Host "Package not yet in winget. Please add new package manually"
        exit 1
    } 
    elseif ($ghVersionCheck.StatusCode -eq 200) {
        Write-Host "Latest version of $wingetPackage $latestVersion is already present in winget."
        exit 0
    }
    else {
        Write-Host "Package $wingetPackage is in winget, but version $latestVersion is not present."
        return $true
    }

}

function Test-PackageAndVersionInWinget {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )
    Write-Host "Checking if $wingetPackage is already in winget and Version $($Latest.Version) already present"

    $progressPreference = 'silentlyContinue'
    $latestWingetMsixBundleUri = $(Invoke-RestMethod https://api.github.com/repos/microsoft/winget-cli/releases/latest).assets.browser_download_url | Where-Object { $_.EndsWith(".msixbundle") }
    $latestWingetMsixBundle = $latestWingetMsixBundleUri.Split("/")[-1]
    Write-Host "Downloading winget to artifacts directory..."
    Invoke-WebRequest -Uri $latestWingetMsixBundleUri -OutFile "./$latestWingetMsixBundle"
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage $latestWingetMsixBundle

    start-sleep 20

    $foundMessage, $textVersion, $separator, $wingetVersions = winget search --id $wingetPackage --source winget --versions

    if (!$wingetVersions) {
        Write-Host "Package not yet in winget. Please add new package manually"
        exit 1
    } 
    elseif ($wingetVersions.contains($latestVersion)) {
        Write-Host "Latest version of $wingetPackage $latestVersion is already present in winget."
        exit 0
    }
    else {
        return $true
    }
}

function Test-ExistingPRs {
    param(
        [Parameter(Mandatory = $true)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName}
    )
    Write-Host "Checking for exisitng PRs for $wingetPackage $($Latest.Version)"
    $ExistingOpenPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'open' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingMergedPRs = gh pr list --search "$($wingetPackage) $($latestVersion) in:title draft:false" --state 'merged' --json 'title,url' --repo 'microsoft/winget-pkgs' | ConvertFrom-Json
    $ExistingPRs = @($ExistingOpenPRs) + @($ExistingMergedPRs)    

    if ($ExistingPRs.Count -gt 0) {
        $ExistingPRs | ForEach-Object {
            Write-Host "Found existing PR: $($_.title)"
            Write-Host "-> $($_.url)"
        }
        exit 0
    }
    else {

        return $true
    }
}

function Get-VersionAndUrl {
    param(
        [Parameter(Mandatory = $false)] [string] $wingetPackage = ${Env:PackageName},
        [Parameter(Mandatory = $false)] [string] $WebsiteURL = ${Env:WebsiteURL}
    )

    $scriptPath = ".\Scripts\Packages\Update-$($wingetPackage).ps1"

    if (-not (Test-Path -Path $scriptPath)) {
        Write-Host "The script '$scriptPath' does not exist. Please check the wingetPackage parameter and the current directory."
        exit 1
    }
    Write-Host "Running $scriptPath"
    $Latest = & $scriptPath -WebsiteURL $WebsiteURL -wingetPackage $wingetPackage


    if (!($Latest | Get-Member -Name "Version") -or !($Latest | Get-Member -Name "URLs")) {

        $lines = $Latest -split "`n" -split " "

        $versionPattern = '^\d+(\.\d+)*$'
        $urlPattern = '^http[s]?:\/\/[^\s]+$'

        $version = $lines | Where-Object { $_ -match $versionPattern }
        $URLs = $lines | Where-Object { $_ -match $urlPattern }

        if ($version -and $URLs) {
            $Latest = @{
                Version = $version
                URLs    = $URLs.split(",").trim().split(" ")
            }
        }
        else {
            Write-Host "No Version ($version) or URL ($($URLs -join ',')) found."
            exit 1
        }
    }

    Write-Host "Found latest version: $version with URLs: $($Latest.URLs -join ',')"
    return $Latest
}
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

function Install-Komac {
    if (-not (Test-Path ".\komac.exe")) {
        #$latestKomacRelease = (Invoke-RestMethod -Uri "https://api.github.com/repos/russellbanks/Komac/releases/latest").assets | Where-Object { $_.browser_download_url.EndsWith("KomacPortable-x64.exe") } | Select-Object -First 1 -ExpandProperty browser_download_url
        $latestKomacRelease = "https://github.com/b0t-at/Komac/releases/download/v2.99/KomacPortable-x64.exe"
        Invoke-WebRequest  -Uri $latestKomacRelease -OutFile komac.exe
    }

    if (Test-Path ".\komac.exe") {
        Write-Host "Komac successfully downloaded"
    }
    else {
        Write-Error "Komac not downloaded"
        exit 1
    }
}

function ConvertTo-Bool {
    param(
        [Parameter(Mandatory = $true)] $input
    )

    if (-not $input) {
        throw "No input provided"
    }

    if ($input -is [bool]) {
        return [bool]$input
    }

    Write-Host "Input: $input"

    switch ($input) {
        "true" { return [bool]$true }
        "false" { return [bool]$false }
        '$true' { return [bool]$true }
        '$false' { return [bool]$false }
        "yes" { return [bool]$true }
        "no" { return [bool]$false }
        "1" { return [bool]$true }
        "0" { return [bool]$false }
        default { throw "Invalid boolean string: $input" }
    }
}

function Update-WingetPackage {
    param(
        [Parameter(Mandatory = $false)] [string] $WebsiteURL,
        [Parameter(Mandatory = $false)] [string] $WingetPackage = ${Env:PackageName},
        [Parameter(Mandatory = $false)][ValidateSet("Komac", "WinGetCreate")] [string] $With = "Komac",
        [Parameter(Mandatory = $false)] [string] $resolves = (${Env:resolves} -match '^\d+$' ? ${Env:resolves} : ""),
        [Parameter(Mandatory = $false)] [bool] $Submit = $false,
        [Parameter(Mandatory = $false)] [string] $latestVersion,
        [Parameter(Mandatory = $false)] [string] $latestVersionURL
    )

    # Custom validation
    if (-not $WebsiteURL -and (-not $latestVersion -or -not $latestVersionURL)) {
        throw "Either WebsiteURL or both latestVersion and latestVersionURL are required."
    }

    # if ($Submit -eq $false) {
    #     $env:DRY_RUN = $true
    # }


    $gitToken = Test-GitHubToken

    if ($latestVersion -and $latestVersionURL) {
        $Latest = @{
            Version = $latestVersion
            URLs    = $latestVersionURL.split(",").trim().split(" ")
        }
    }
    else {
        Write-Host "Getting latest version and URL for $wingetPackage from $WebsiteURL"
        $Latest = Get-VersionAndUrl -wingetPackage $wingetPackage -WebsiteURL $WebsiteURL
    }

    if ($null -eq $Latest) {
        Write-Host "No version info found"
        exit 1
    }
    Write-Host $Latest
    Write-Host $($Latest.Version)
    Write-Host $($Latest.URLs)

    $prMessage = "Update version: $wingetPackage version $($Latest.Version)"

    $PackageAndVersionInWinget = Test-PackageAndVersionInGithub -wingetPackage $wingetPackage -latestVersion $($Latest.Version)

    $ManifestOutPath = "./"

    if ($PackageAndVersionInWinget) {

        $ExistingPRs = Test-ExistingPRs -wingetPackage $wingetPackage -latestVersion $($Latest.Version)
        
        if ($ExistingPRs) {
            Write-Host "Downloading $With and open PR for $wingetPackage Version $($Latest.Version)"
            Switch ($With) {
                "Komac" {
                    Install-Komac
                    .\komac.exe update --identifier $wingetPackage --version $Latest.Version --urls ($Latest.URLs).split(" ") ($Submit -eq $true ? '-s' : '--dry-run') ($resolves -match '^\d+$' ? "--resolves" : $null ) ($resolves -match '^\d+$' ? $resolves : $null ) -t $gitToken --output "$ManifestOutPath"
                }
                "WinGetCreate" {
                    Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
                    if (Test-Path ".\wingetcreate.exe") {
                        Write-Host "wingetcreate successfully downloaded"
                    }
                    else {
                        Write-Error "wingetcreate not downloaded"
                        exit 1
                    }
                    .\wingetcreate.exe update $wingetPackage ($Submit -eq $true ? "-s" : $null ) -v $Latest.Version -u ($Latest.URLs).split(" ") --prtitle $prMessage -t $gitToken -o $ManifestOutPath
                }
                default { 
                    Write-Error "Invalid value \"$With\" for -With parameter. Valid values are 'Komac' and 'WinGetCreate'"
                }
            }
        }
    }
}

function Get-LatestMongoDBVersions {
    param(
        [Parameter(Mandatory = $true)] [string] $WebsiteURL,
        [Parameter(Mandatory = $true)] [string] $PackageFilter
    )

    $website = Invoke-WebRequest -Uri $WebsiteURL
    $content = $website.Content

    $links = $content | Select-String -Pattern 'https?://[^"]+' -AllMatches | % { $_.Matches } | % { $_.Value }
    $msilinks = $links | Select-String -Pattern 'https?://[^\s]*\.msi' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }

    $Packagelinks = $msilinks | Select-String -Pattern "https?://[^\s]*$PackageFilter[^\s]*\.msi" -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Where-Object { $_ -notmatch "$PackageFilter-isolated|$PackageFilter-readonly" }

    $versions = $Packagelinks | ForEach-Object { $_ -match '(\d+\.\d+\.\d+(-rc\d*|-beta\d*)?)' | Out-Null; $matches[1] }
    $stableVersions = $versions | Where-Object { $_ -notmatch '(-rc|beta)' }

    $latestVersion = $stableVersions | Sort-Object { [Version]$_ } | Select-Object -Last 1
    $latestVersionUrl = $Packagelinks | Where-Object { $_ -match $latestVersion }

    return @{
        Version = $latestVersion
        Url     = $latestVersionUrl
    }
}

function Get-MSIFileInformation {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebsiteURL
    ) 

    $latestVersionUrl = $WebsiteURL
    $DownloadFileName = [System.IO.Path]::GetFileName($latestVersionUrl)
    Invoke-WebRequest -Uri $latestVersionUrl -OutFile $DownloadFileName

    # If the file is a ZIP file, unzip it and search for .exe or .msi files
    if ($DownloadFileName -like "*.zip") {
        $UnzipPath = "."
        Expand-Archive -Path $DownloadFileName -DestinationPath $UnzipPath
        $FileName = Get-ChildItem -Path $UnzipPath -Include "*.exe", "*.msi" -Recurse | Select-Object -First 1
    }
    else {
        $FileName = $DownloadFileName
    }

    # Get the full file path
    $FullFilePath = (Resolve-Path $FileName).Path

    [System.IO.FileInfo]$FilePath = New-Object System.IO.FileInfo($FullFilePath)

  
    # https://learn.microsoft.com/en-us/windows/win32/msi/installer-opendatabase
    $msiOpenDatabaseModeReadOnly = 0
    
    $productLanguageHashTable = @{
        '1025' = 'Arabic'
        '1026' = 'Bulgarian'
        '1027' = 'Catalan'
        '1028' = 'Chinese - Traditional'
        '1029' = 'Czech'
        '1030' = 'Danish'
        '1031' = 'German'
        '1032' = 'Greek'
        '1033' = 'English'
        '1034' = 'Spanish'
        '1035' = 'Finnish'
        '1036' = 'French'
        '1037' = 'Hebrew'
        '1038' = 'Hungarian'
        '1040' = 'Italian'
        '1041' = 'Japanese'
        '1042' = 'Korean'
        '1043' = 'Dutch'
        '1044' = 'Norwegian'
        '1045' = 'Polish'
        '1046' = 'Brazilian'
        '1048' = 'Romanian'
        '1049' = 'Russian'
        '1050' = 'Croatian'
        '1051' = 'Slovak'
        '1053' = 'Swedish'
        '1054' = 'Thai'
        '1055' = 'Turkish'
        '1058' = 'Ukrainian'
        '1060' = 'Slovenian'
        '1061' = 'Estonian'
        '1062' = 'Latvian'
        '1063' = 'Lithuanian'
        '1081' = 'Hindi'
        '1087' = 'Kazakh'
        '2052' = 'Chinese - Simplified'
        '2070' = 'Portuguese'
        '2074' = 'Serbian'
    }

    $summaryInfoHashTable = @{
        1  = 'Codepage'
        2  = 'Title'
        3  = 'Subject'
        4  = 'Author'
        5  = 'Keywords'
        6  = 'Comment'
        7  = 'Template'
        8  = 'LastAuthor'
        9  = 'RevisionNumber'
        10 = 'EditTime'
        11 = 'LastPrinted'
        12 = 'CreationDate'
        13 = 'LastSaved'
        14 = 'PageCount'
        15 = 'WordCount'
        16 = 'CharacterCount'
        18 = 'ApplicationName'
        19 = 'Security'
    }

    $properties = @('ProductVersion', 'ProductCode', 'ProductName', 'Manufacturer', 'ProductLanguage', 'UpgradeCode')
   
    try {

        $file = Get-ChildItem -Path $FilePath -ErrorAction Stop

    }
    catch {
        Write-Warning "Unable to get file $FilePath $($_.Exception.Message)"
        exit 1
    }

    $object = [PSCustomObject][ordered]@{
        FileName     = $file.Name
        FilePath     = $file.FullName
        'Length(MB)' = $file.Length / 1MB
    }

    # Read property from MSI database
    $windowsInstallerObject = New-Object -ComObject WindowsInstaller.Installer

    # open read only    
    $msiDatabase = $windowsInstallerObject.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstallerObject, @($file.FullName, $msiOpenDatabaseModeReadOnly))

    foreach ($property in $properties) {
        $view = $null
        $query = "SELECT Value FROM Property WHERE Property = '$($property)'"
        $view = $msiDatabase.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $msiDatabase, ($query))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)

        try {
            $value = $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
        }
        catch {
            Write-Verbose "Unable to get '$property' $($_.Exception.Message)"
            $value = ''
        }
        
        if ($property -eq 'ProductLanguage') {
            $value = "$value ($($productLanguageHashTable[$value]))"
        }

        $object | Add-Member -MemberType NoteProperty -Name $property -Value $value
    }

    $summaryInfo = $msiDatabase.GetType().InvokeMember('SummaryInformation', 'GetProperty', $null, $msiDatabase, $null)
    $summaryInfoPropertiesCount = $summaryInfo.GetType().InvokeMember('PropertyCount', 'GetProperty', $null, $summaryInfo, $null)

    (1..$summaryInfoPropertiesCount) | ForEach-Object {
        $value = $SummaryInfo.GetType().InvokeMember("Property", "GetProperty", $Null, $SummaryInfo, $_)

        if ($null -eq $value) {
            $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value ''
        }
        else {
            $object | Add-Member -MemberType NoteProperty -Name $summaryInfoHashTable[$_] -Value $value
        }
    }

    #$msiDatabase.GetType().InvokeMember('Commit', 'InvokeMethod', $null, $msiDatabase, $null)
    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
 
    # Run garbage collection and release ComObject
    $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($windowsInstallerObject) 
    [System.GC]::Collect()

    return $object  
} 



# function Start-Update {
#     $wingetPackage = ${Env:PackageName}
#     $url = ${Env:WebsiteURL}
#     $Latest = Get-VersionAndUrl -wingetPackage $wingetPackage -WebsiteURL $url

#     Update-WingetPackage -WingetPackage $wingetPackage -latestVersion $Latest.Version -with Komac -latestVersionUrls $Latest.URLs
# }



$wingetPackage = ${Env:PackageName}
$WebsiteURL = ${Env:WebsiteURL}
