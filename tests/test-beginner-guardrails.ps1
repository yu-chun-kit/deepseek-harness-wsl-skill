$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repoRoot 'deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1'
$linuxHelperPath = Join-Path $repoRoot 'deepseek-harness-wsl\scripts\setup-in-wsl.sh'
$readmePath = Join-Path $repoRoot 'README.md'
$resourceReferencePath = Join-Path $repoRoot 'deepseek-harness-wsl\references\resources.md'

$installer = Get-Content -Raw -LiteralPath $installerPath
$linuxHelper = Get-Content -Raw -LiteralPath $linuxHelperPath
$readme = Get-Content -Raw -LiteralPath $readmePath
$resourceReference = Get-Content -Raw -LiteralPath $resourceReferencePath

$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($installerPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) {
    throw "PowerShell parser reported errors: $($errors.Message -join '; ')"
}

if ($installer -notmatch '\[bool\]\$InstallWslIfMissing\s*=\s*\$false') {
    throw 'Fresh WSL installation must be opt-in by default.'
}
if ($installer -notmatch '\$Action -ne ''install''') {
    throw 'Only the install action may enter the WSL platform-install flow.'
}
if ($installer -notmatch 'DeepSeek has not published a supported Harness RAM minimum') {
    throw 'The installer must disclose the absent official RAM sizing guidance.'
}
if ($installer -match '(?im)^\s*(Set-Content|Add-Content|Out-File).*\.wslconfig') {
    throw 'The installer must not write .wslconfig.'
}
if (($installer + $readme + $resourceReference) -match '(?im)^\s*memory\s*=\s*2GB\s*$') {
    throw 'The project must not ship a generic 2GB WSL cap.'
}
if ($linuxHelper -notmatch 'major == 22 && minor >= 19 \|\| major >= 24') {
    throw 'Linux Node compatibility must follow the current official source support range.'
}
if ($readme -notmatch '-InstallWslIfMissing:\$true' -or $readme -notmatch '(Native Windows|原生 Windows)') {
    throw 'README must document the explicit WSL opt-in and native Windows choice.'
}
if ($resourceReference -notmatch 'all WSL2 distributions' -or $resourceReference -notmatch 'concurrent-session formula') {
    throw 'The resource guide must explain global scope and unsupported session sizing.'
}

$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$escapedInstallerPath = $installerPath.Replace("'", "''")

$statusCommand = "`$env:PATH=''; & '$escapedInstallerPath' -Action status"
$statusOutput = @(& $windowsPowerShell -NoProfile -Command $statusCommand 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0 -or $statusOutput -notmatch 'Status only: no changes made') {
    throw 'A missing-WSL status request must succeed without installing anything.'
}

$installCommand = "`$env:PATH=''; & '$escapedInstallerPath' -Action install"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $installOutput = @(& $windowsPowerShell -NoProfile -Command $installCommand 2>&1) -join "`n"
    $installExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($installExitCode -eq 0 -or $installOutput -notmatch 'WSL installation is opt-in') {
    throw 'A missing-WSL install request must refuse platform installation without explicit opt-in.'
}

$previewCommand = "`$env:PATH=''; & '$escapedInstallerPath' -Action install -InstallWslIfMissing:`$true -WhatIf"
$previewOutput = @(& $windowsPowerShell -NoProfile -Command $previewCommand 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0 -or $previewOutput -notmatch 'WSL distribution Ubuntu-24.04') {
    throw 'Explicit missing-WSL WhatIf must preview the platform addition without requiring elevation.'
}

$wrongDistroCommand = "`$env:PATH=''; & '$escapedInstallerPath' -Action install -Distribution Fedora -InstallWslIfMissing:`$true -WhatIf"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $wrongDistroOutput = @(& $windowsPowerShell -NoProfile -Command $wrongDistroCommand 2>&1) -join "`n"
    $wrongDistroExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}
if ($wrongDistroExitCode -eq 0 -or $wrongDistroOutput -notmatch 'will not silently substitute') {
    throw 'An explicit missing distribution must never be replaced with the Ubuntu baseline.'
}

Write-Host 'Beginner WSL/resource guardrail assertions passed.'
