$WebsiteUrl = "https://docs.konnekt.io/changelog"

$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]

$ProductName = ($PackageName).Trim().ToLower()

$URLFilter = "$($ProductName)-(X86|X64|Arm64)-(\d+\.\d+\.\d+\.\d+).Msi"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL

# Extract the content of the webpage
$WebsiteLinks = $website.Links
$WebsiteContent = $website.Content

$FilteredLinks = $WebsiteLinks | Where-Object { $_.href -match $URLFilter }

$latestVersion = $FilteredLinks | ForEach-Object { $_.href -replace '.*-(\d+\.\d+\.\d+\.\d+).*', '$1' } | Sort-STNumerical -Descending | Select-Object -First 1

$latestVersionUrl = $FilteredLinks.href | Where-Object { ($_ -match $latestVersion) } | Where-Object { $_ -ne '' }


# Use regex to extract the content between "2.20.1.0" and "Downloads"
$Pattern = '\.?2\.10\.1\.0(.*?)Downloads'
if ($WebsiteContent -match $Pattern) {
    $ExtractedContent = $matches[1]
    Write-Output "Extracted Content:"
    Write-Output $ExtractedContent
} else {
    Write-Output "Pattern not found in the content."
}

return $latestVersion, $latestVersionUrl