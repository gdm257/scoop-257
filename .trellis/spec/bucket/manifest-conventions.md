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
- 需要 tag 前缀/上下文锚定义版本、又想兼容本地无 token 的 HTML 模式验证时，用双模式锚：`(?:/releases/tag/|^)(…)`（先例：ffmpegfreeui、inkeys）

### 默认 regex 的截断缺陷

`"checkver": "github"` 不带 `regex` 时，默认 `(?:v|V)?([\d.-]+)` 有两类截断缺陷，凡 tag 带下列形态的 manifest 必须显式写 regex 捕获完整版本：

| tag 形态 | 默认产出 | 应捕获 | 先例 |
| -------- | -------- | ------ | ---- |
| prerelease `v1.4.0-rc.1` | 畸形 `1.4.0-` | `1.4.0-rc.1` | — |
| 字母后缀 `v0.7.7beta` / `20260713a` | 截断 `0.7.7` / `20260713` | 完整含后缀 | OnscripterYuri、inkeys |
| 下划线后缀 `v0.8.1_upd1` | 截断 `0.8.1` | `0.8.1_upd1` | dismtools |
| monorepo tag 后缀 `v1.1.9_snow-shot` | 截断 `1.1.9`（拼 tag 404） | `1.1.9`，tag 段后缀以字面量进模板 | snowshot |

### autoupdate 与 checkver 捕获组的耦合

checkver regex 的命名组（`(?<base>…)`）与 autoupdate 的 `$matchBase` 模板是上下游契约；用 `replace` 时同理。改 checkver regex 前先查 autoupdate 引用了哪些组，不得破坏。

### Pattern: 资产锚定 checkver（部分发布 / 幽灵版本）

**Problem**: 上游部分发布（如 KataGo 补丁版只重编部分后端）或 tag 与资产不同步时，`releases/latest` 的 tag 版本可能没有目标资产 → autoupdate 拼出 404。atom feed 还会被 draft release 污染（版本只在 feed、API/资产不存在，见 pdf-guru）。

**Solution**: checkver 直接锚定资产 URL 本身——`checkver.url` 指向 releases API 列表，regex 用反向引用匹配完整资产名，捕获版本：

```json
"checkver": {
    "url": "https://api.github.com/repos/lightvector/KataGo/releases?per_page=100",
    "regex": "releases/download/v([\\d.]+)/katago-v\\1-opencl-windows-x64\\.zip"
}
```

- 语义：按 release 顺序找**第一条**含匹配资产的记录 → 拿到该资产真实存在的最新版本，自动跳过无此资产的更新版
- 反向引用 `\\1` 保证 tag 版本与资产内嵌版本一致；正则错一个字符即失配（响亮失败，优于静默 404）
- 先例：veyon、katago 家族×5、pdf-guru
- 代价：每个锚定 manifest 为 excavator run 增加 1 次匿名 API 调用
- 注意：手动 bump pinned 状态时 hash 必须填真值（GitHub API 资产的 digest 字段即 sha256）——version == checkver 结果时 autoupdate 不会触发，占位 hash 会永久滞留（先例：katago-tensorrt 1.18.1 六条真哈希）

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

### atom feed 被 draft release 污染

**Symptom**: checkver 拿到的版本在 releases API 与资产清单中均不存在（幽灵版本），autoupdate 404。

**Cause**: `releases.atom` 包含 draft releases——draft 只出现在 feed，API `/releases` 与下载均不可见。

**Fix/Prevention**: 换资产锚定 checkver（见上文 Pattern），直接以真实资产存在性定版本（先例：pdf-guru 自愈回 1.0.12）。

### excavator 失败 triage（月度）

excavator job 整体永远 success——checkver/autoupdate 失败不 fail build，只会刷日志。定期（建议月度）拉日志分类，不同类处置路径不同：

| 日志特征 | 分类 | 处置 |
| -------- | ---- | ---- |
| `couldn't match '<regex>' in …` | checkver regex 失配 | 对照真实 `tag_name` 改 regex（见"checkver 两种匹配模式"） |
| 版本尾随 `-`（如 `1.4.0-`） | 默认 regex 吞 prerelease | 补显式 regex 捕获完整后缀 |
| `X: v (scoop version is y) autoupdate available` 后接 `URL … is not valid` | 资产 URL 漂移（B2 类） | 对照 release 实际资产名改 autoupdate.url 模板 |
| checkver URL 本身 404/超时 | 上游死亡 | 查证后移 `deprecated/`；仅搬家则换源 |
| `X: v (scoop version is y)` 无 `autoupdate available` | 无 autoupdate 或版本语义错 | 补配置或修 regex 使版本可比 |

修复验证顺序：regex 以 API 模式（裸 tag_name）为准 → 会触发新版本的用 HEAD 验证拼出的 URL → 最终回归看下一轮 excavator 日志。

### 批量修复的分派核对

批量 triage 修复（数十个 manifest）时两处曾出错，务必核对：

- **分派清单必须由 input 失败清单生成**（逐行映射），不得从 prd 方案表手抄——方案表手写曾漏 1 项（snowshot），沿 prd→分派 链静默传播；check 阶段必须对账「input 行数 == prd 方案数 == 实际改动数」
- **research 结论含 checkver regex 时必须按 API 模式语义验证**（裸 `tag_name`，见"checkver 两种匹配模式"）并注明验证模式——HTML 模式验证通过的正则在 excavator 下可能永远失配（先例：inkeys，靠实现代理读 scoop 源码拦截）

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
