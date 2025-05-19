$WebsiteUrl = "https://docs.konnekt.io/changelog"

$versionParts = $wingetPackage.Split('.')
$PackageName = $versionParts[1]
$ProductName = ($PackageName).Trim().ToLower()
$URLFilter = "$($ProductName)-(X86|X64|Arm64)-(\d+\.\d+\.\d+\.\d+).Msi"

# Download the webpage
$website = Invoke-WebRequest -Uri $WebsiteURL -UseBasicParsing

# Extract the content of the webpage
$WebsiteLinks = $website.Links
$WebsiteContent = $website.Content

$FilteredLinks = $WebsiteLinks | Where-Object { $_.href -match $URLFilter }
$latestVersion = $FilteredLinks | ForEach-Object { $_.href -replace '.*-(\d+\.\d+\.\d+).*', '$1' } | Get-STNumericalSorted -Descending | Select-Object -First 1
$latestVersionUrl = $FilteredLinks.href | Where-Object { ($_ -match $latestVersion) } | Where-Object { $_ -ne '' }

$htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
$htmlDocument.LoadHtml($Website)

# Select all h3 elements
$h3Elements = $htmlDocument.DocumentNode.SelectNodes('//h3')
$targetElement = $null

foreach ($element in $h3Elements) {
    if ($element.InnerText -match $latestVersion -or $element.InnerText -match $latestVersion.trim(".0")) {
        $targetElement = $element
        break
    }
}

if ($null -ne $targetElement) {
    # Extract content until the next h3 element
    $content = ""
    $releaseNotes = ""
    $currentElement = $targetElement.NextSibling

    while ($null -ne $currentElement -and $currentElement.Name -ne "h3") {
        #$currentElement.InnerText
        if ($currentElement.InnerText -match "Downloads") {
            break
        }
        if ($currentElement.InnerText -match "Add" -or $currentElement.InnerText -match "Fix") {
            $content += "* " + $currentElement.InnerText + "`n"
            foreach ($listItem in $currentElement.NextSibling.ChildNodes) {
                $content += "  - " + $listItem.InnerText + "`n"
            }
        }
        #$content += $currentElement.InnerText + "`n"
        $currentElement = $currentElement.NextSibling
    }

    # Convert the extracted content to YAML format
    $yamlContent = "ReleaseNotes: |-`n"
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        $yamlContent += "  $line`n"
    }

    #Write-Host "YAML Content:"
    #Write-Host $yamlContent

    $releaseNotes = $yamlContent

}
else {
    Write-Host "Version not found in the content."
}

$releaseNotes = $releaseNotes.trim() + "`nReleaseNotesUrl: $WebsiteUrl"

return [PSCustomObject]@{
    Version = $latestVersion
    URLs = $latestVersionUrl
    ReleaseNotes = $releaseNotes
  }
