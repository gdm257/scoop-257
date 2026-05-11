# Scoop Bucket Manifest Conventions

## Commit Messages

| Area                   | Style                      | Example                              |
| ---------------------- | -------------------------- | ------------------------------------ |
| Manifest / app files   | `<appname>: <description>` | `moonlight: Add version 6.2.79`      |
| Trellis / CI / tooling | `ci(<scope>): <message>`   | `ci(sdd): upgrade opencode package`  |
| Spec docs              | `docs(spec): <message>`    | `docs(spec): add bucket conventions` |

## Manifest Variables

| Variable        | Description                                         |
| --------------- | --------------------------------------------------- |
| `$dir`          | `~/scoop/apps/<app>/<version>`                      |
| `$persist_dir`  | `~/scoop/persist/<app>`                             |
| `$bucketsdir`   | `~/scoop/buckets`                                   |
| `$bucket`       | **Bucket name (string)**, e.g. `"gdm257"`           |
| `$version`      | Manifest `version` field                            |
| `$architecture` | `64bit` / `32bit` / `arm64`                         |
| `$app`          | App name                                            |
| `$fname`        | Downloaded file name                                |
| `$cmd`          | Running command: `install` / `uninstall` / `update` |
| `$baseurl`      | Base URL for hash/checkver                          |
| `$global`       | `$true` if `-g` flag used                           |

> `$bucket` is the **name**, not a path. Use `Join-Path $bucketsdir $bucket` to build full path.

## Helper Functions

| Function                   | Usage                                                  |
| -------------------------- | ------------------------------------------------------ |
| `appdir <name> $global`    | Resolve app directory, e.g. `$(appdir foobar $global)` |
| `Find-BucketDirectory`     | Alternative to `Join-Path $bucketsdir $bucket`         |
| `Add-Path` / `Remove-Path` | Manage shim PATH entries                               |

## Manifest Field Reference

### Core Fields

| Field         | Required | Description                                                |
| ------------- | -------- | ---------------------------------------------------------- |
| `version`     | yes      | Semver string, or `"latest"` for non-versioned apps        |
| `description` | yes      | One-line summary                                           |
| `homepage`    | yes      | Project URL                                                |
| `license`     | yes      | SPDX identifier, or `Freeware` / `Proprietary` / `Unknown` |

### Download & Extract

| Field          | Description                                                                           |
| -------------- | ------------------------------------------------------------------------------------- |
| `url`          | String or array. Top-level for single-arch; inside `architecture` for multi-arch      |
| `hash`         | `"sha256:..."` / `"sha512:..."` or plain hex string. Omit if `checkver` auto-resolves |
| `architecture` | Object with `64bit` / `32bit` / `arm64` keys, each containing `url` + `hash`          |
| `extract_dir`  | Subdirectory to extract from archive (discard wrapper dir)                            |
| `extract_to`   | Target subdirectory in `$dir` to extract into. `""` = flatten into `$dir` root        |
| `innosetup`    | `true` — treat Inno Setup `.exe` as self-extracting archive                           |

**URL fragment trick**: Append `#/dl.7z` or `#/name.exe` to force Scoop to treat the download as a different format:

```json
"url": "https://example.com/app-setup.exe#/dl.7z"
```

### Dependencies

| Field     | Format                                | Description                               |
| --------- | ------------------------------------- | ----------------------------------------- |
| `depends` | `["innoextract"]`                     | Hard dependency — installed automatically |
| `suggest` | `{"vcredist": "extras/vcredist2022"}` | Soft suggestion — shown to user           |

Cross-bucket refs: `"main/7zip"`, `"extras/vcredist2022"`.

### Scripts (run in order)

| Field          | Timing                    | Typical Use                                |
| -------------- | ------------------------- | ------------------------------------------ |
| `pre_install`  | Before file extraction    | Rename files, set up vars                  |
| `installer`    | After extraction          | Run setup, copy bucket scripts into `$dir` |
| `post_install` | After installer + persist | Clone repos, initialize config             |

All accept string or array of strings (PowerShell). Use `$dir`, `$persist_dir`, `$bucketsdir`, `$bucket`.

### bin

```json
"bin": "app.exe"                           // shim name = file name
"bin": ["sub/app.exe", "alias"]            // custom shim name
"bin": ["sub/app.exe", "alias", "args"]    // extra args prepended to user args
"bin": [["run.ps1", "gitea-mirror"]]       // wrap PowerShell scripts as CLI
```

### shortcuts

```json
"shortcuts": [["app.exe", "Start Menu Name"]]
```

Creates Start Menu `.lnk`. **Warning**: CJK/emoji names break due to ANSI COM API ([Scoop#2585](https://github.com/ScoopInstaller/Scoop/issues/2585)).

### persist

```json
"persist": "data"                    // single dir/file
"persist": ["profiles", "app.json"]  // multiple
```

- Directories → **junction** `$dir/X` ↔ `$persist_dir/X`
- Files → **hardlink** `$dir/X` ↔ `$persist_dir/X`
- `scoop reset` overwrites `$dir` with `$persist_dir` on conflict (no merge)

### notes

```json
"notes": "Single string"
"notes": ["Line 1", "", "Line 3"]
```

Displayed after install. Use for setup instructions, caveats.

### checkver / autoupdate

```json
"checkver": "github"                          // GitHub releases, auto-detect version
"checkver": { "url": "...", "regex": "..." }  // Custom page + regex, first capture = version
"checkver": { "github": "https://...", "regex": "v([\\d.]+)" }
```

```json
"autoupdate": {
    "architecture": {
        "64bit": { "url": "https://.../$version/...-$version-win64.zip" }
    },
    "hash": { "url": "$url.sha256" }            // auto-fetch hash from sibling file
}
```

`$version` is interpolated from checkver result.

## Portable Manifests

- No `uninstaller` needed — Scoop removes `$dir` on uninstall
- Copy reusable scripts from `scripts/` via installer:
    ```powershell
    Copy-Item (Join-Path $bucketsdir $bucket 'scripts\<name>') (Join-Path $dir 'shim') -Recurse -Force
    ```

## Gotchas

### Shim Mechanism

Each shim = `name.exe` + `name.ps1` in `~/scoop/shims/`. All `.exe` identical (same MD5); `.ps1` contains target path. Doesn't pollute PATH.

### CreateShortcut CJK Encoding

COM `WScript.Shell.CreateShortcut` uses ANSI — non-system-default characters produce `??`. No upstream fix since 2018.

### Bucket Repair

`scoop bucket rm <name> && scoop bucket add <name>` — fastest fix for broken bucket state.

## Pattern: which-shim

Generic PATH-based command fallback. Candidates as semicolon-separated first argument.

**Repo**: `scripts/which-shim/which.ps1` + `which.cmd`

```json
{
    "installer": {
        "script": "Copy-Item (Join-Path $bucketsdir $bucket 'scripts\\which-shim') (Join-Path $dir 'shim') -Recurse -Force"
    },
    "bin": [["shim\\which.cmd", "python3", "python3.exe;python.exe"]]
}
```

Flow: `python3` → `which.cmd` → `which.ps1` splits `$args[0]` on `;` → `Get-Command` per candidate → exec first match with remaining args.
