# Scoop Bucket Manifest Conventions

## Key Scoop Installer Variables

| Variable       | Value                              | Example                                      |
| -------------- | ---------------------------------- | -------------------------------------------- |
| `$dir`         | App install directory              | `C:\Users\<user>\scoop\apps\<app>\<version>` |
| `$bucketsdir`  | Base buckets directory             | `C:\Users\<user>\scoop\buckets`              |
| `$bucket`      | **Bucket name (string), NOT path** | `gdm257`                                     |
| `$persist_dir` | Persist directory                  | `C:\Users\<user>\scoop\persist\<app>`        |

### Common Mistake: $bucket Path Construction

```powershell
# WRONG — $bucket is just the name "gdm257", not a path
Join-Path $bucket 'scripts\which-shim'
# → C:\Users\demo\scoop\buckets\gdm257\gdm257\scripts\... (doubled!)

# CORRECT — join $bucketsdir + $bucket first
Join-Path $bucketsdir $bucket 'scripts\which-shim'
# → C:\Users\demo\scoop\buckets\gdm257\scripts\...
```

## Scoop Manifest Requirements

### Architecture Check

Scoop requires a `url` field (or per-architecture `url` in `architecture` section) to determine supported architectures. Without it, install fails with `"doesn't support current architecture"`.

For installer-script-only manifests (no real download needed), use a placeholder URL with a real file and hash:

```json
{
    "url": "https://raw.githubusercontent.com/python/cpython/v3.12.8/LICENSE",
    "hash": "3b2f81fe21d181c499c59a256c8e1968455d6689d269aa85373bfb6af41da3bf"
}
```

### Bin Field — Triple Format

```json
"bin": [["relative\\path\\to.exe", "alias_name", "extra_args"]]
```

- Creates a shim named `alias_name` that calls `exe` with `extra_args` prepended to user args
- `extra_args` is a single string; use a delimiter (e.g., `;`) to encode multiple values

### Portable Manifests

- No `uninstaller` script needed — Scoop removes `$dir` entirely on uninstall
- Installer scripts should copy files from the bucket repo into `$dir`, not generate inline
- Store reusable scripts under `scripts/` in the repo; installer copies them via `$bucketsdir $bucket`

## Pattern: Generic Which-Shim

A reusable PowerShell script that finds and executes the first available command from a candidate list.

**Location**: `scripts/which-shim/which.ps1` + `which.cmd`

**Usage in manifest**:

```json
{
    "installer": {
        "script": "Copy-Item -Path (Join-Path $bucketsdir $bucket 'scripts\\which-shim') -Destination (Join-Path $dir 'shim') -Recurse -Force"
    },
    "bin": [["shim\\which.cmd", "python3", "python3.exe;python.exe"]]
}
```

**How it works**:

1. Scoop creates `python3.cmd` shim → calls `which.cmd python3.exe;python.exe <user_args>`
2. `which.cmd` delegates to `which.ps1`
3. `which.ps1` splits `$args[0]` on `;` → iterates candidates via `Get-Command` → execs first match
