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

`--global` 只改变安装目录和作用域；脚本仍在启动 `scoop` 的当前 PowerShell 进程内，以该进程的 Windows 用户/token 执行。全局安装要求当前进程是管理员，但 Scoop 不会切换到 `SYSTEM`，也不会为脚本单独提权。

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

### checkver 两种匹配模式（关键）

`checkver.github`（含自定义 `regex`）的行为取决于环境有无 `GITHUB_TOKEN`（excavator CI 有，本地一般没有）：

| 模式 | 触发条件 | regex 匹配对象 | 可用锚 |
| ---- | -------- | -------------- | ------ |
| **API 模式** | 环境有 `GITHUB_TOKEN` | `/releases/latest` 的裸 `tag_name`（JSON `$.tag_name`） | 只能匹配 tag 本体 |
| HTML 模式 | 无 token | releases/latest 页面 HTML 源码 | `releases/tag/…`、`<title>`、资产名等 |

本 bucket 的主运行环境是 excavator（API 模式），所以：

- regex **不得**带 `releases/tag/`、`<title>` 等 HTML 锚——API 模式下永远失配，日志表现为 `couldn't match 'releases/tag/…'`
- 版本只在 release **name**（tag 是 `26`/`untagged-<hash>`）的项目，用显式 `checkver.url` 指向 releases/latest 页面 + 匹配标题的 regex
- 想锁定稳定版/主版本（跳过 prerelease）：用 `https://github.com/<repo>/releases.atom` + `</title>` 锚定 regex（注意 atom 只含最新 ~10 条）

### 默认 regex 的破折号缺陷

`"checkver": "github"` 不带 `regex` 时，默认 `(?:v|V)?([\d.-]+)` 遇 prerelease tag（如 `v1.4.0-rc.1`）产出畸形版本 `1.4.0-`。凡上游存在 prerelease tag 的 manifest 必须显式写 regex 并捕获完整后缀。

### autoupdate 与 checkver 捕获组的耦合

checkver regex 的命名组（`(?<base>…)`）与 autoupdate 的 `$matchBase` 模板是上下游契约；用 `replace` 时同理。改 checkver regex 前先查 autoupdate 引用了哪些组，不得破坏。

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

### checkver regex 在 API 模式失配

**Symptom**: excavator 日志大量 `couldn't match 'releases/tag/…' in api.github.com/…/releases/latest`，本地 `scoop checkver` 却通过。

**Cause**: 本地走 HTML 模式，excavator 带 token 走 API 模式，regex 只匹配裸 `tag_name`（见上文"checkver 两种匹配模式"）。

**Prevention**: 写/改 checkver regex 时以 API 模式为准；本地验证可用带 token 的请求对照 `tag_name`。

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
