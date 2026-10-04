[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('status', 'install', 'update', 'uninstall')]
    [string]$Action = 'status',
    [string]$Distribution,
    [ValidateSet('standard', 'code', 'cordis', 'all')]
    [string]$Mode = 'all',
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wsl-distributions.ps1')
if ($env:OS -ne 'Windows_NT') { throw 'Run this entry point from Windows PowerShell.' }
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'WSL is not installed. Install Harness first.' }

$distributions = @(Get-WslDistributions)
if ($Distribution) {
    if ($Distribution -notin $distributions) { throw "Distribution '$Distribution' is not installed." }
    $selected = $Distribution
} elseif ($distributions.Count -eq 1) {
    $selected = $distributions[0]
} elseif ($distributions.Count -eq 0) {
    throw 'No non-Docker WSL distribution is installed. Install Harness first.'
} else {
    throw "Multiple WSL distributions are installed. Choose -Distribution explicitly: $($distributions -join ', ')"
}

Assert-Wsl2Distribution -Distribution $selected -VerboseLines @(& wsl.exe --list --verbose 2>$null)

$helper = Join-Path $PSScriptRoot 'manage-anchored-presets-in-wsl.sh'
if (-not (Test-Path -LiteralPath $helper)) { throw "Missing helper: $helper" }
$arguments = @('./manage-anchored-presets-in-wsl.sh', '--action', $Action, '--mode', $Mode)
if ($Yes) { $arguments += '--yes' }
if ($WhatIfPreference) { $arguments += '--dry-run' }

Write-Host "Distribution: $selected"
Write-Host "Action:       $Action"
Write-Host "Mode:         $Mode"
& wsl.exe --distribution $selected --cd $PSScriptRoot -- bash @arguments
if ($LASTEXITCODE -ne 0) { throw "Anchored preset helper failed with exit code $LASTEXITCODE." }
