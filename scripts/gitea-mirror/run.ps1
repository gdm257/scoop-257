#!/usr/bin/env pwsh
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeFile = "$dir\.runtime"

$runtimeMap = @{
    'bun'   = @{ cmd = 'bun';   run = 'run start' }
    'npm'   = @{ cmd = 'npm';   run = 'run start' }
    'pnpm'  = @{ cmd = 'pnpm';  run = 'run start' }
    'yarn'  = @{ cmd = 'yarn';  run = 'start' }
    'deno'  = @{ cmd = 'deno';  run = 'run --allow-all start' }
}

# Try saved runtime first
$cmd = $null
$runArgs = $null
if (Test-Path $runtimeFile) {
    $saved = Get-Content $runtimeFile | Select-Object -First 1
    if ($runtimeMap.ContainsKey($saved)) {
        $cmd = $runtimeMap[$saved].cmd
        $runArgs = $runtimeMap[$saved].run
    }
}

# Fallback: detect
if (-not $cmd) {
    foreach ($rt in $runtimeMap.GetEnumerator()) {
        try {
            $null = & $rt.Value.cmd --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $cmd = $rt.Value.cmd
                $runArgs = $rt.Value.run
                break
            }
        } catch { continue }
    }
}

if (-not $cmd) {
    Write-Error 'No runtime found. Install bun, nodejs-lts, pnpm, yarn, or deno.'
    exit 1
}

$fullCmd = "$cmd $runArgs $args"
Write-Host "Running: $fullCmd" -ForegroundColor Cyan
Invoke-Expression "cd '$dir'; $fullCmd"
