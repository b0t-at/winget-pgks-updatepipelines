. .\scripts\common.ps1

$latestVersion = Invoke-RestMethod -Method Get -Uri "https://oliverbetz.de/cms/files/Artikel/ExifTool-for-Windows/exiftool_latest_version.txt"

$validUrls = @("$WebsiteURL/ExifTool_install_$($latestVersion)_32.exe","$WebsiteURL/ExifTool_install_$($latestVersion)_64.exe")

foreach($url in $validUrls)
{
    $response = Invoke-WebRequest -Uri $url -Method Head
    if($response.StatusCode -ne 200)
    {
        throw "URL $url is not valid."
        exit 1
    }
}

return $latestVersion, $validUrls