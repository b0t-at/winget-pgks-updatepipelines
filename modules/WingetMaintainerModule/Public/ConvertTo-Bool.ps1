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
