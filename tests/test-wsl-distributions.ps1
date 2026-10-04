$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'deepseek-harness-wsl/scripts/wsl-distributions.ps1')

function wsl.exe {
    "Ubuntu`0"
    "docker-desktop`0"
    "docker-desktop-data`0"
    ''
}

$distros = @(Get-WslDistributions)
if ($distros.Count -ne 1 -or $distros[0] -ne 'Ubuntu') { throw 'A single distro must remain a complete name.' }
Assert-Wsl2Distribution -Distribution $distros[0] -VerboseLines @('* Ubuntu Running 2')
Assert-Wsl2Distribution -Distribution 'Ubuntu [work]' -VerboseLines @("* Ubuntu [work] 停止 2`0")

foreach ($rows in @(@('* Ubuntu Running 1'), @('* Ubuntu-24.04 Running 2'), @('NAME STATE VERSION'), @('* Ubuntu Running 2', 'Ubuntu Stopped 2'))) {
    $rejected = $false
    try { Assert-Wsl2Distribution -Distribution 'Ubuntu' -VerboseLines $rows } catch { $rejected = $true }
    if (-not $rejected) { throw "Unconfirmed WSL2 selection was accepted: $rows" }
}

# Exercise both entry points with one mocked distro, including the forwarded name.
function wsl.exe {
    if ($args[0] -eq '--list') {
        if ($args[1] -eq '--verbose') { '* Ubuntu Running 2' } else { "Ubuntu`0" }
    } elseif ($args[0] -eq '--distribution') {
        if ($args[1] -ne 'Ubuntu') { throw "Forwarded a truncated distro name: $($args[1])" }
        $global:WslDistributionTestForwarded = $true
    }
    $global:LASTEXITCODE = 0
}
foreach ($entry in @('setup-deepseek-harness-wsl.ps1', 'manage-anchored-presets.ps1')) {
    $global:WslDistributionTestForwarded = $false
    & (Join-Path $repoRoot "deepseek-harness-wsl/scripts/$entry") -Action status
    if (-not $global:WslDistributionTestForwarded) { throw "Did not invoke the Linux helper: $entry" }
}
Remove-Item Function:wsl.exe
Remove-Variable WslDistributionTestForwarded -Scope Global
Write-Host 'WSL distribution selection assertions passed.'
