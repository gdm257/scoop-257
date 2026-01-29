# Gitea Mirror installer script
param($dir, $persist_dir)

# Change to install directory
Push-Location $dir

# Ensure persist dir exists
New-Item -ItemType Directory -Force -Path $persist_dir | Out-Null

# Copy run.ps1 to $dir
Copy-Item "$bucketsdir\gdm257\scripts\gitea-mirror\run.ps1" "$dir\run.ps1" -Force

# Detect available runtime
$runtimes = @(
    @{ name = 'bun';   cmd = 'bun';   run = 'run start' },
    @{ name = 'npm';   cmd = 'npm';   run = 'run start' },
    @{ name = 'pnpm';  cmd = 'pnpm';  run = 'run start' },
    @{ name = 'yarn';  cmd = 'yarn';  run = 'start' },
    @{ name = 'deno';  cmd = 'deno';  run = 'run --allow-all start' }
)

$selected = $null
foreach ($rt in $runtimes) {
    try {
        $null = & $rt.cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $selected = $rt
            Write-Host "Using $($rt.name)"
            break
        }
    } catch { continue }
}

if (-not $selected) {
    Pop-Location
    Write-Error "No runtime found (bun/npm/pnpm/yarn/deno)" -ErrorAction Stop
}

Write-Host 'Installing dependencies...'
if ($selected.name -eq 'deno') {
    deno run --allow-all --reload -E "import(https://deno.land/x/deno_install/install.sh)"
} else {
    & $selected.cmd install
}

Write-Host 'Building...'
& $selected.cmd run build 2>&1 | Out-Null

Write-Host 'Initializing database...'
& $selected.cmd run manage-db init

# Copy .env.example to .env if .env doesn't exist
if (-not (Test-Path ".\.env")) {
    Copy-Item ".\.env.example" ".\.env" -Force
    Write-Host 'Created .env from .env.example. Edit it before use.'
}

# Save runtime to $dir (Scoop will persist it)
$selected.name | Set-Content ".\.runtime"

Pop-Location
