# python3-shim manifest

## Goal

Create a Scoop manifest that provides a `python3` command on Windows, falling back through a list of candidate executables found in PATH.

## Requirements

- A **generic which-shim script** (`scripts/which-shim/which.ps1` + `which.cmd`) that accepts a semicolon-separated candidate list as its first argument, searches PATH in order, and forwards remaining args to the first match
- A **manifest** (`bucket/python3-shim.json`) that:
    - Uses a placeholder download URL (Python LICENSE) to satisfy Scoop's architecture check
    - Installer copies the generic shim from `$bucketsdir\$bucket\scripts\which-shim` into `$dir\shim`
    - `bin` field maps `python3` → `which.cmd` with candidates `python3.exe;python.exe`
- Fully portable: no uninstaller script needed (Scoop removes `$dir` automatically)
- No zip archives in git

## Files

- `scripts/which-shim/which.ps1` — PowerShell shim: splits `$args[0]` on `;`, iterates candidates via `Get-Command`, execs first match
- `scripts/which-shim/which.cmd` — cmd wrapper calling which.ps1
- `bucket/python3-shim.json` — Scoop manifest

## Scope

- Single-purpose shim; the generic which-shim can be reused by other manifests with different candidate lists
