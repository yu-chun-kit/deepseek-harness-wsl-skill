[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('status', 'install', 'update', 'uninstall')]
    [string]$Action = 'install',
    [string]$Distribution,
    [ValidateSet('latest', 'next')]
    [string]$Channel = 'latest',
    [ValidateSet('auto', 'npm', 'pnpm')]
    [string]$PackageManager = 'auto',
    [string]$PackageVersion,
    [ValidateRange(0, 10)]
    [int]$FetchRetries = 4,
    [ValidateRange(30, 900)]
    [int]$FetchTimeoutSeconds = 300,
    [ValidateRange(1, 50)]
    [int]$NetworkConcurrency = 15,
    [ValidateRange(1, 3)]
    [int]$DownloadAttempts = 2,
    [ValidateSet('auto', 'skip')]
    [string]$NativeBuildTools = 'auto',
    [switch]$AcceptPrerelease,
    [switch]$Yes,
    [switch]$SkipNodeInstall,
    [bool]$InstallWslIfMissing = $false
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

function Show-HostResourceSummary {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $computer = Get-CimInstance Win32_ComputerSystem
        $totalGiB = [math]::Round(($computer.TotalPhysicalMemory / 1GB), 1)
        $availableGiB = [math]::Round(($os.FreePhysicalMemory * 1KB / 1GB), 1)
        $logicalProcessors = $computer.NumberOfLogicalProcessors
        $systemDriveName = $env:SystemDrive.TrimEnd(':')
        $systemDrive = Get-PSDrive -Name $systemDriveName -ErrorAction Stop
        $freeDiskGiB = [math]::Round(($systemDrive.Free / 1GB), 1)

        Write-Host "Host resources: ${totalGiB} GiB RAM (${availableGiB} GiB currently available), $logicalProcessors logical CPU(s), ${freeDiskGiB} GiB free on $($env:SystemDrive)."
    } catch {
        Write-Warning 'Could not read the complete Windows RAM/CPU/system-drive summary. This does not block inspection.'
    }

    $wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
    if (Test-Path -LiteralPath $wslConfigPath) {
        Write-Host 'WSL resource config: an existing global %USERPROFILE%\.wslconfig was detected; this skill will not read, overwrite, or merge it automatically.'
    } else {
        Write-Host 'WSL resource config: no global %USERPROFILE%\.wslconfig detected; this skill will not create one automatically.'
    }
    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        $runningDistributions = @(@(& wsl.exe --list --running --quiet 2>$null) |
            ForEach-Object { ($_ -replace "`0", '').Trim() } |
            Where-Object { $_ })
        if ($runningDistributions.Count -gt 0) {
            Write-Host "WSL currently running: $($runningDistributions -join ', '). This is observed state, not proof that Harness started them."
        } else {
            Write-Host 'WSL currently running: none reported.'
        }
    }
    Write-Host 'Sizing: DeepSeek has not published a supported Harness RAM minimum or a per-session RAM formula. A 2 GiB WSL cap is not treated as an official recommendation.'
}

function Show-WslChoiceNotice {
    Write-Host ''
    Write-Host 'No usable non-Docker WSL distribution is installed.'
    Write-Host 'Choice 1 - Native Windows: official Harness supports Windows; install a supported Windows Node.js and use the official npm package without adding WSL.'
    Write-Host 'Choice 2 - WSL2 compatibility path: choose this when Linux/Bash tool semantics are the goal. It adds an Ubuntu virtual disk, a Linux account, and may require elevation and a reboot.'
    Write-Host 'WSL starts when WSL or a dependent app invokes it, and WSL manages the VM lifecycle. Open handles, settings, and idle management affect observed state; a Linux background service alone does not guarantee that the VM stays running.'
    Write-Host 'This skill never creates a 2 GiB cap, edits .wslconfig, or promises a fixed number of concurrent Harness sessions.'
}

function Install-WslBaseline {
    Show-WslChoiceNotice
    if ($Distribution -and $Distribution -ne $script:UbuntuBaseline) {
        throw "Distribution '$Distribution' is not installed. This helper only bootstraps $script:UbuntuBaseline and will not silently substitute it for an explicitly requested distribution."
    }
    if ($Action -ne 'install') {
        if ($Action -eq 'status') {
            Write-Host 'Status only: no changes made.'
            exit 0
        }
        throw "Action '$Action' cannot add a missing WSL environment. Choose native Windows or run -Action install with an explicit WSL opt-in first."
    }
    if (-not $InstallWslIfMissing) {
        throw "WSL installation is opt-in. Use native Windows, or rerun with -InstallWslIfMissing:`$true to add $script:UbuntuBaseline after reviewing the tradeoffs."
    }
    if (-not (Test-IsAdministrator) -and -not $WhatIfPreference) {
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

Show-HostResourceSummary

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

$arguments = @(
    './setup-in-wsl.sh',
    '--action', $Action,
    '--channel', $Channel,
    '--package-manager', $PackageManager,
    '--fetch-retries', $FetchRetries,
    '--fetch-timeout-seconds', $FetchTimeoutSeconds,
    '--network-concurrency', $NetworkConcurrency,
    '--download-attempts', $DownloadAttempts,
    '--native-build-tools', $NativeBuildTools
)
if ($PackageVersion) { $arguments += @('--package-version', $PackageVersion) }
if ($AcceptPrerelease) { $arguments += '--accept-prerelease' }
if ($Yes) { $arguments += '--yes' }
if ($SkipNodeInstall) { $arguments += '--skip-node-install' }
if ($WhatIfPreference) { $arguments += '--dry-run' }

Write-Host "Distribution: $selectedDistribution"
Write-Host "Action:       $Action"
Write-Host "Pkg manager:  $PackageManager"
Write-Host "Network:      $FetchRetries fetch retries, ${FetchTimeoutSeconds}s timeout, $NetworkConcurrency connection(s), $DownloadAttempts install attempt(s)"
Write-Host "Build tools:  $NativeBuildTools"

& wsl.exe --distribution $selectedDistribution --cd $PSScriptRoot -- bash @arguments
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "WSL helper failed with exit code $exitCode."
}
