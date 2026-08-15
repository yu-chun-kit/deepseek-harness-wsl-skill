[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('status', 'install', 'update', 'uninstall')]
    [string]$Action = 'install',
    [string]$Distribution,
    [ValidateSet('latest', 'next')]
    [string]$Channel = 'latest',
    [string]$PackageVersion,
    [switch]$AcceptPrerelease,
    [switch]$Yes,
    [switch]$SkipNodeInstall,
    [bool]$InstallWslIfMissing = $true
)

$ErrorActionPreference = 'Stop'
$script:UbuntuBaseline = 'Ubuntu-24.04'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WslDistributions {
    $items = @(& wsl.exe --list --quiet 2>$null)
    return @($items | ForEach-Object { ($_ -replace "`0", '').Trim() } |
        Where-Object { $_ -and $_ -notmatch '^docker-desktop(?:-data)?$' })
}

function Install-WslBaseline {
    if (-not $InstallWslIfMissing) {
        throw "No usable WSL distribution was found. Re-run without -InstallWslIfMissing:`$false to install $script:UbuntuBaseline."
    }
    if (-not (Test-IsAdministrator)) {
        throw "Installing WSL requires an elevated PowerShell. Re-run this command as Administrator; the script never self-elevates."
    }
    if ($PSCmdlet.ShouldProcess("WSL distribution $script:UbuntuBaseline", 'Install')) {
        & wsl.exe --install --distribution $script:UbuntuBaseline --no-launch
        if ($LASTEXITCODE -ne 0) {
            throw "wsl --install failed with exit code $LASTEXITCODE."
        }
        Write-Host "WSL installation phase completed. If Windows requests a reboot, reboot manually."
        Write-Host "Then launch $script:UbuntuBaseline once, create the Linux user, and rerun this same installer."
    }
    exit 0
}

if ($env:OS -ne 'Windows_NT') {
    throw 'Run this PowerShell entry point on Windows. The Linux helper is invoked inside WSL.'
}

$wslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wslCommand) {
    Install-WslBaseline
}

$distributions = Get-WslDistributions
if ($Distribution) {
    if ($Distribution -notin $distributions) {
        if ($distributions.Count -eq 0) { Install-WslBaseline }
        throw "Distribution '$Distribution' is not installed. Available: $($distributions -join ', ')"
    }
    $selectedDistribution = $Distribution
} elseif ($distributions.Count -eq 0) {
    Install-WslBaseline
} elseif ($distributions.Count -eq 1) {
    $selectedDistribution = $distributions[0]
} else {
    throw "Multiple WSL distributions are installed. Choose one explicitly with -Distribution. Available: $($distributions -join ', ')"
}

$verboseList = @(& wsl.exe --list --verbose 2>$null) -join "`n"
$cleanVerboseList = $verboseList -replace "`0", ''
$selectedPattern = [regex]::Escape($selectedDistribution)
$selectedLine = ($cleanVerboseList -split "`r?`n" | Where-Object { $_ -match $selectedPattern } | Select-Object -First 1)
if ($selectedLine -and $selectedLine -notmatch '\s2\s*$') {
    throw "'$selectedDistribution' is not confirmed as WSL2. This skill will not convert it automatically."
}

$windowsScriptPath = Join-Path $PSScriptRoot 'setup-in-wsl.sh'
if (-not (Test-Path -LiteralPath $windowsScriptPath)) {
    throw "Missing Linux helper: $windowsScriptPath"
}

$arguments = @('./setup-in-wsl.sh', '--action', $Action, '--channel', $Channel)
if ($PackageVersion) { $arguments += @('--package-version', $PackageVersion) }
if ($AcceptPrerelease) { $arguments += '--accept-prerelease' }
if ($Yes) { $arguments += '--yes' }
if ($SkipNodeInstall) { $arguments += '--skip-node-install' }
if ($WhatIfPreference) { $arguments += '--dry-run' }

Write-Host "Distribution: $selectedDistribution"
Write-Host "Action:       $Action"

& wsl.exe --distribution $selectedDistribution --cd $PSScriptRoot -- bash @arguments
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "WSL helper failed with exit code $exitCode."
}
