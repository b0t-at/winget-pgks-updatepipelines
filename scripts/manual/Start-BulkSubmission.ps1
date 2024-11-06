function Start-BulkSubmission {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $PRTitlePrefix,
        [Parameter(Mandatory = $true)] [string] $Token,
        [Parameter(Mandatory = $true)] [bool] $Replace
    )

    #check if wingetcreate is installed
    if (-not (Test-Path .\wingetcreate.exe)) {
        # Install wingetcreate
        Invoke-WebRequest https://aka.ms/wingetcreate/latest -OutFile wingetcreate.exe
    }

    #get folder
    $folder = Get-ChildItem -Path $Path -Directory
    #get subfolder names
    $subfolders = $folder | Select-Object -ExpandProperty Name
    #loop through subfolders
    foreach($folder in $subfolders) {
        # get full path
        $fullPath = Join-Path -Path $Path -ChildPath $folder
        .\wingetcreate.exe submit $fullPath  --prtitle $PRTitlePrefix -t $gitToken
    }
    
}