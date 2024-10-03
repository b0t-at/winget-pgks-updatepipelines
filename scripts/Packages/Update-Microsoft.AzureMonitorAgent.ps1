. .\scripts\common.ps1

$website = $WebsiteURL
$absoluteURL=[System.Net.HttpWebRequest]::Create($website).GetResponse().ResponseUri.AbsoluteUri
$versionWebsite = Invoke-WebRequest -Method Get "https://raw.githubusercontent.com/MicrosoftDocs/azure-docs/main/articles/azure-monitor/agents/azure-monitor-agent-extension-versions.md"
$lines = $versionWebsite.Content -split "`n"

# Find the index of the table header separator
$schema = "| Release Date | Release notes | Windows | Linux |"
$index = $lines.IndexOf($schema)
# get column index of Windows in schema
$columnIndex = $schema.Split("|").IndexOf(" Windows ")
# Find the index of the table header separator
$versionInfo = $lines[$index + 2].Split("|")[$columnIndex].Trim()

return $versionInfo, $absoluteURL
