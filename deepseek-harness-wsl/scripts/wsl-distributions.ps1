function Get-WslDistributions {
    $items = @(& wsl.exe --list --quiet 2>$null)
    return @($items | ForEach-Object { ($_ -replace "`0", '').Trim() } |
        Where-Object { $_ -and $_ -notmatch '^docker-desktop(?:-data)?$' })
}

function Assert-Wsl2Distribution {
    param(
        [Parameter(Mandatory = $true)][string]$Distribution,
        [Parameter(Mandatory = $true)][string[]]$VerboseLines
    )

    $cleanList = ($VerboseLines -join "`n") -replace "`0", ''
    $escapedName = [regex]::Escape($Distribution)
    $pattern = "^\s*\*?\s*$escapedName\s+\S+\s+(?<version>[12])\s*$"
    $rows = @($cleanList -split "`r?`n" | Where-Object { $_ -match $pattern })
    if ($rows.Count -ne 1 -or $rows[0] -notmatch $pattern -or $Matches['version'] -ne '2') {
        throw "'$Distribution' is not confirmed as WSL2. This skill will not convert it automatically."
    }
}
