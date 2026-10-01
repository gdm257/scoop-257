# Research: B2 asset-404 — 第 26–37 项（project-86 → OnscripterYuri）+ kotlin-lsp

- **Query**: 修复 excavator autoupdate 资产 404：对每项读旧 autoupdate 模板、查上游真实资产名、归纳新命名模式、HEAD 验证新模板、注明连带改动 / deprecate 候选
- **Scope**: mixed（本地 manifests + GitHub API 匿名查询 + JetBrains CDN 探测 + zip 中央目录清点）
- **Date**: 2026-10-01
- **方法说明**: bash 被门禁拦截（与上轮相同），全部网络探测改在 eval 内核用 `python urllib.request`（User-Agent `scoop-bucket-research-assetmapc`，全部带 timeout）。GitHub API 共 17 次（ratelimit 余量充足）。HEAD 验证走 `urllib`（跟随 302 至 objects.githubusercontent.com）。

## TL;DR 总表

| # | manifest | 根因 | 结论 | 新模板验证 |
|---|---|---|---|---|
| 26 | project-86 | 上游停止 GitHub 发版，转 itch.io；latest tag 零资产 | **DEPRECATE 候选 / BLOCKED** | — |
| 27 | micyou | v2.0.0 起便携 zip → Inno Setup 安装器 | 改模板 + `innosetup` + 删 extract_dir | 200 |
| 28 | snowshot | tag 自 v1.1.8 起加 `_snow-shot` 后缀（monorepo） | 改 checkver regex + 模板 tag 段 | 200 |
| 29 | SymlinkCreator | v2.0.0 起文件名去版本号、按架构拆分 | 改模板 → `Symlink.Creator.x64.zip` | 200 |
| 30 | SunshineGameFinder | 1.14.0 起裸 exe → 版本化 zip | 改模板 + 去掉 `#/…exe` 改名后缀 | 200 |
| 31 | sudocode | v0.2.0 零资产，发行已转 npm（1.2.0） | **DEPRECATE 候选 / BLOCKED** | — |
| 32 | tagstudio | v9.6.1 起资产名带 `_v<版本>` | 改模板 | 200 |
| 33 | speedynote | x86 安装器 `_x86` → `_x86_32`（v1.6.0 起） | 仅改 32bit 模板 | 200×3 |
| 34 | project-graph | v4.2.1 起 GitHub 只发 GPU 版安装器 | 改模板 → `_x64-setup-gpu.exe` | 200 |
| 35 | vibe-around | 资产名改为 `VibeAround-Windows-x64-Portable-<v>.zip` | 改模板（+可选 checkver 加固） | 200 |
| 36 | whoami | v1.12.0 零资产（疑似 goreleaser 发布失败） | **BLOCKED**：pin 到 1.11.x 或等上游修复 | v1.11.0=200 / v1.12.0=404 |
| 37 | OnscripterYuri | checkver 默认 regex 截断 `v0.7.7beta` → `0.7.7` | 改 checkver regex，模板不变 | 200×2 |
| +13 | kotlin-lsp | JetBrains CDN 全面改址改名（263.4702.0 起） | 改 host/path/文件名；bin 不变 | 200×3 |

（# 编号 = `input-failures.md` 表格行序，project-86 为第 26 项；kotlin-lsp 为表格第 13 项，由主代理单独指派给本报告）

---

## 逐项明细

### 26. project-86 — DEPRECATE 候选（上游发行移至 itch.io）

- **旧模板**: `https://github.com/Taliayaya/Project-86/releases/download/v$version/Project86-v$version.zip`（version `1.11.1-alpha`）
- **真实上游状态**（API, 2026-10-01）:
  - latest 非 prerelease = `v2.0.0-alpha.2`（2026-09-13）**零资产**。release body 原文（关键证据）：
    > "# /!\\ DOWNLOAD HERE -> https://project-86.itch.io/project-86 — For user experience, we now publish the releases through itch.io. GitHub is also no longer used in preference to Unity VCS. … Repository can sometimes be synced but do not expect it to be in a working state or up to date."
  - `v2.0.0-alpha.1`（**prerelease=true**）才有资产：`Project86-v2.0.0-alpha.1.zip`（HEAD 200，但 2,032,548,385 字节 ≈ 2GB）。checkver 走 `releases/latest` 永远选不中 prerelease。
  - `v1.11.1-alpha`（当前 manifest 版本）资产仍在（模板本身有效）。
  - repo 未归档，pushed_at=2026-09-20（代码偶尔同步，但发行渠道已迁走）。
- **新模板**: 无 —— 上游已无 GitHub 资产可指。
- **验证**: `v2.0.0-alpha.1/Project86-v2.0.0-alpha.1.zip` → 200（仅 prerelease tag，checkver 不可达）；latest tag 无任何资产。
- **连带改动 / 建议**: **deprecate（移除 manifest）**。若保留只能手工钉死在 1.11.1-alpha 并删 checkver/autoupdate；itch.io 无稳定直链（需 itch API），不适合 autoupdate。**BLOCKED**。

### 27. micyou — v2.0.0 起 Windows 只发 Inno Setup 安装器

- **旧模板**: `.../releases/download/v$version/MicYou-Win-$version.zip`（便携 zip，extract_dir `MicYou`）
- **真实资产**（`v2.0.3`，latest 非 prerelease 2026-09-05）:
  - `MicYou-Win-2.0.3-installer.exe` ← 唯一 Windows 资产
  - v2.0.0 / 2.0.1 / 2.0.3 全部只有 `-installer.exe`（v2.0.0-alpha.1 曾是 `-installer.msi`）；便携 zip 已不存在。
  - 安装器探测（下载 31,525,476 字节全文扫描）：`Inno Setup` 标记 ×3（首现 offset 742156），无 `Nullsoft`；PE machine=0x014c（32 位 stub，Inno 常态，不能据此推断应用位数）。
- **新模板**:
  ```json
  "url": "https://github.com/LanRhyme/MicYou/releases/download/v$version/MicYou-Win-$version-installer.exe"
  ```
- **验证**: HEAD 200（31,525,476 字节）。
- **连带改动**:
  - 删除 `"extract_dir": "MicYou"`；新增 `"innosetup": true`（参考本 bucket `speedynote.json` 的 Inno 处理方式）。
  - shortcuts `MicYou.exe` 保留 [INFERENCE：内层 exe 名未解包验证，1.x zip 内为 MicYou.exe，实现时可用 innounp 复核]。
  - checkver 不变（tag `v2.0.3` → 默认 regex 捕获 `2.0.3` 正确）。

### 28. snowshot — tag 加 `_snow-shot` 后缀（monorepo snow-apps）

- **旧模板**: `.../releases/download/v$version/snow-shot-$version-windows-x64-portable.zip`，checkver `"github"` 无 regex
- **真实上游状态**:
  - latest 非 prerelease = tag **`v1.1.9_snow-shot`**（2026-10-01 09:58Z 发布 —— 就是本轮 excavator 跑挂的那版）。资产 `snow-shot-1.1.9-windows-x64-portable.zip` **名字没变**。
  - 默认 regex `([\d.-]+)` 在 tag `v1.1.9_snow-shot` 上捕获 `1.1.9`，旧模板拼出 tag 路径 `v1.1.9` → 404。**根因是 tag 后缀，不是资产名。**
  - 后缀规律：v1.1.5-beta~v1.1.7-beta 无后缀；v1.1.8、v1.1.9 带 `_snow-shot`（repo 是含 snow-shot / snow-shot-mini 的 monorepo，同 tag 同时挂两套资产，如 `snow-shot-mini-1.1.9-windows-x64-portable.zip`）。
- **新 checkver + 模板**:
  ```json
  "checkver": {
      "github": "https://github.com/mg-chao/snow-apps",
      "regex": "v([\\d.]+(?:-beta\\d*)?)_snow-shot(?!-)"
  },
  "autoupdate": {
      "architecture": { "64bit": {
          "url": "https://github.com/mg-chao/snow-apps/releases/download/v$version_snow-shot/snow-shot-$version-windows-x64-portable.zip"
      } }
  }
  ```
  regex 说明：捕获裸版本 `1.1.9`，`_snow-shot` 字面锚定 tag 后缀，`(?!-)` 排除未来独立发布的 `..._snow-shot-mini` tag；API 模式（excavator）匹配裸 tag_name，HTML 模式同样可命中页面里的 tag 串。tag 段 `_snow-shot` 以字面量进 URL。
- **验证**: 新 URL `.../download/v1.1.9_snow-shot/snow-shot-1.1.9-windows-x64-portable.zip` → 200（81,575,802 字节）；旧 URL `.../download/v1.1.9/...` → 404。
- **连带改动**: 结构不变（同 portable zip；extract_dir `bin`、bin/shortcuts/persist 保留）。可选增强：release 附带 `.zip.sha256`（实测内容 `0f8c64…fa322  snow-shot-…zip`），可加 `"hash": {"url": "$baseurl.sha256"}`。脆弱性：上游若再去掉 tag 后缀，checkver 会 "couldn't match"（响亮失败，可接受）。

### 29. SymlinkCreator — 文件名去版本号 + 按架构拆分

- **旧模板**: `.../releases/download/v$version/Symlink.Creator.$version.zip`
- **真实资产**（`v2.0.1`，latest 2026-08-29；v2.0.0 同命名，连续 2 版）:
  - `Symlink.Creator.x64.zip`（14,719,812 字节）
  - `Symlink.Creator.arm64.zip`（13,973,866 字节）
  - （v1.3.0 及以前是单文件 `Symlink.Creator.zip` / `Symlink.Creator.<v>.zip`）
- **新模板**:
  ```json
  "url": "https://github.com/arnobpl/SymlinkCreator/releases/download/v$version/Symlink.Creator.x64.zip"
  ```
- **验证**: HEAD 200；zip 全 39 项已清点：根目录含 `SymlinkCreator.exe` ✓（另有 `SymlinkCreator.Launcher.exe`），WinUI3 自包含部署（Microsoft.WindowsAppRuntime.\*.dll 全随包）。
- **连带改动**: bin `SymlinkCreator.exe`、shortcuts、`extract_to": ""` 均不变（根目录展开）。可选：补 arm64 architecture（`Symlink.Creator.arm64.zip`）。

### 30. SunshineGameFinder — 裸 exe → 版本化 zip

- **旧模板**: `.../releases/download/$version/SunshineGameFinder-win-x64.exe#/SunshineGameFinder.exe`（tag 无 `v` 前缀）
- **真实资产**（tag `1.14.0`，latest 2026-10-01；1.13.1 及以前是裸 `SunshineGameFinder-win-x64.exe`）:
  - `SunshineGameFinder-1.14.0-win-x64.zip`（6,910,526 字节）
  - `SunshineGameFinder-1.14.0-win-arm64.zip`、linux/osx tar.gz、`SHA256SUMS.txt`
- **新模板**:
  ```json
  "url": "https://github.com/JMTK/SunshineGameFinder/releases/download/$version/SunshineGameFinder-$version-win-x64.zip"
  ```
- **验证**: HEAD 200；zip 内容清点：**单条目 `SunshineGameFinder.exe`** ✓；旧 URL `.../1.14.0/SunshineGameFinder-win-x64.exe` → 404。
- **连带改动**: 删除 URL 尾部 `#/SunshineGameFinder.exe` 改名后缀（zip 内文件名已正确）；bin `SunshineGameFinder.exe` 不变；`"bin"` 无需其它调整。可选：补 arm64 architecture。

### 31. sudocode — DEPRECATE 候选（GitHub 资产停发，发行转 npm）

- **旧模板**: `.../releases/download/v$version/sudocode-$version-win-x64.zip`（extract_dir `sudocode-$version-win-x64`；version `0.1.26`）
- **真实上游状态**:
  - latest 非 prerelease = `v0.2.0`（2026-03-18）**零资产**；其后 6.5 个月无任何新 release。repo pushed_at=2026-03-18（同步停更），未归档，293 星。
  - **npm `sudocode` 活跃**：latest `1.2.0`，近期版本 1.1.20…1.2.0（远超 GitHub 的 0.2.0）→ CLI 发行渠道已迁 npm。
  - v0.1.26 资产仍在（HEAD 200，108,191,762 字节）。
- **新模板**: 无 —— v0.2.0 起上游 GitHub 无任何资产。
- **验证**: v0.1.26 资产 200（血统正常）；latest 无资产可验证。
- **连带改动 / 建议**: **deprecate（移除 manifest）**，或由维护者决定改写为 npm/nodejs 型 manifest（超出本任务范围）。**BLOCKED**。

### 32. tagstudio — 资产名加版本号前缀（v9.6.1 起）

- **旧模板**: `.../releases/download/v$version/tagstudio_windows_x86_64_portable.zip`（无版本号文件名）
- **真实资产**（`v9.6.3`，latest 2026-08-15；v9.6.1/v9.6.2/v9.6.3 连续 3 版同规律；v9.6.0 及更早才是无版本名）:
  - `tagstudio_v9.6.3_windows_x86_64_portable.zip`（155,945,134 字节）等 6 资产
- **新模板**:
  ```json
  "url": "https://github.com/TagStudioDev/TagStudio/releases/download/v$version/tagstudio_v$version_windows_x86_64_portable.zip"
  ```
- **验证**: HEAD 200。
- **连带改动**: 无（同 portable zip；shortcuts `TagStudio.exe` 不变）。checkver 不变（`v9.6.3` → `9.6.3`）。

### 33. speedynote — 32 位安装器改名 `_x86` → `_x86_32`

- **旧模板**: 64bit `SpeedyNoteInstaller_$version_amd64.exe#/dl.exe`、32bit `..._$version_x86.exe#/dl.exe`、arm64 `..._$version_arm64.exe#/dl.exe`
- **真实资产**（`v1.6.3`，latest 2026-09-03；v1.6.0/1.6.1/1.6.2/1.6.3 连续 4 版同规律）:
  - `SpeedyNoteInstaller_1.6.3_amd64.exe`（不变）
  - `SpeedyNoteInstaller_1.6.3_x86_32.exe` ← **改名点**（v1.5.3 及以前是 `_x86.exe`）
  - `SpeedyNoteInstaller_1.6.3_arm64.exe`（不变）
- **新模板（仅 32bit）**:
  ```json
  "url": "https://github.com/alpha-liu-01/SpeedyNote/releases/download/v$version/SpeedyNoteInstaller_$version_x86_32.exe#/dl.exe"
  ```
- **验证**: HEAD 200 ×3（amd64 53MB / x86_32 43MB / arm64 51.7MB）。
- **连带改动**: 无（`innosetup: true` 已有，shortcuts 不变）。

### 34. project-graph — GitHub 只剩 GPU 版安装器

- **旧模板**: `.../releases/download/v$version/Project.Graph_$version_x64-setup.exe#/app.7z`（version `3.2.3`）
- **真实资产**（`v4.2.4`，latest 非 prerelease 2026-09-06；**v4.2.1/4.2.2/4.2.3/4.2.4 + nightly 连续 5 个 tag 同规律**）:
  - Windows exe 仅 `Project.Graph_4.2.4_x64-setup-gpu.exe`（9,950,596 字节）
  - 另有 `Project.Graph_4.2.4_x64-setup.exe-gpu.sig`（上游签名文件命名错乱：给 `x64-setup.exe` 的 sig 被命名成 `x64-setup.exe-gpu.sig`），**plain `x64-setup.exe` 自 v4.2.1 起消失**
  - 其余为 deb/rpm/dmg/app.tar.gz
- **新模板**:
  ```json
  "url": "https://github.com/LiRenTech/project-graph/releases/download/v$version/Project.Graph_$version_x64-setup-gpu.exe#/app.7z"
  ```
- **验证**: GPU 版 HEAD 200；plain `Project.Graph_4.2.4_x64-setup.exe` HEAD 404（确证消失）。
- **连带改动**: 提取机制 `#/app.7z` + `extract_to": ""` 沿用（同为 NSIS/Tauri 安装器，旧机制在 3.2.3 有效）；shortcuts 不变。注：GPU 变体对用户显卡有要求（Flutter GPU 渲染），描述/notes 可提一句；上游若恢复 plain 版需回改模板。

### 35. vibe-around — 资产全套改名

- **旧模板**: `.../releases/download/v$version/VibeAround-win-$version-portable.zip`（version `0.7.6`）
- **真实资产**（`v0.7.25`，latest 2026-08-30；v0.7.23/24/25 连续 3 版同规律）:
  - `VibeAround-Windows-x64-Portable-0.7.25.zip`（29,327,263 字节）← 命名从 `win-<v>-portable` 改为 `Windows-x64-Portable-<v>`
  - 另有 `VibeAround-Windows-x64-Setup-0.7.25.exe`、`...-MSI-...msi`、Linux AppImage/deb、macOS dmg
- **新模板**:
  ```json
  "url": "https://github.com/jazzenchen/VibeAround/releases/download/v$version/VibeAround-Windows-x64-Portable-$version.zip"
  ```
- **验证**: HEAD 200。
- **连带改动**: 无（portable zip；shortcuts `VibeAround.exe` 不变）。
- **可选加固（本次 404 的根因之外的隐患）**: repo 有双系列 tag —— 桌面 `v0.7.x` 与 CLI `va-v0.0.x`，均非 prerelease、同日交错发布（v0.7.25 与 va-v0.0.14 相差 29 分钟）。若未来 CLI tag 更新，`releases/latest` 会返回 `va-v0.0.15`，默认 regex 捕获 `0.0.15` 导致版本回退式误更新。建议 checkver 加 `"regex": "^v([\\d.]+)"`（API 模式对裸 tag_name 匹配；`^` 锚定使 `va-v…` 无法命中）。注意该 regex 在无 token 的 HTML 模式下会失效（excavator 恒有 token，不受影响）。

### 36. whoami — v1.12.0 零资产（上游发布故障）→ BLOCKED

- **旧模板**: `.../releases/download/v$version/whoami_v$version_windows_amd64.zip`（+ arm64；version `1.11.0`）
- **真实上游状态**:
  - latest 非 prerelease = `v1.12.0`（2026-07-30）**零资产、release body 为空**。v1.11.0 与 v1.12.0 之间无其它 release。
  - 前一版 `v1.11.0`（2025-03-13）资产齐全，命名与现模板完全一致（`whoami_v1.11.0_windows_amd64.zip` 等 9 资产）；v1.10.x 亦然。
  - repo 活着（traefik 官方，1425 星，pushed 2026-07-29，未归档）。
  - **判断**: 发布方式未变化（无 docker-only 公告、无说明，body 全空）——更像 goreleaser 资产上传失败的孤立事故。模板本身无需也不应改动。
- **验证**: `v1.12.0/whoami_v1.12.0_windows_amd64.zip` → 404（复现失败）；`v1.11.0/whoami_v1.11.0_windows_amd64.zip` → 200（模板血统正常）。
- **建议（二选一，均不改 autoupdate 模板）**:
  1. **pin checkver 至 1.11.x** 直至上游带资产发新版：
     ```json
     "checkver": {
         "url": "https://github.com/traefik/whoami/releases.atom",
         "regex": "<title[^>]*>v(1\\.11\\.\\d+)</title>"
     }
     ```
     （返回 `1.11.0` = 当前 manifest 版本 → checkver 绿、不触发 autoupdate；上游发 v1.12.1+ 带资产后需放宽 regex）
  2. 维持现状等待上游修复（excavator 每轮继续报 404 噪音）。
  不建议 deprecate（项目健康、仅单次发布事故）。

### 37. OnscripterYuri — checkver 默认 regex 截断 `beta` 后缀（模板本身没错）

- **旧模板**: `.../releases/download/v$version/onsyuri_v$version_{x64,x86}_win.exe#/onsyuri.exe`（version `0.7.6`）
- **真实上游状态**:
  - latest 非 prerelease = tag **`v0.7.7beta`**（2026-06-23）。资产 `onsyuri_v0.7.7beta_x64_win.exe`、`onsyuri_v0.7.7beta_x86_win.exe` —— **命名规律与旧模板一致**（版本号嵌入资产名）。
  - 根因：checkver `"github"` 无 regex → 默认 `([\d.-]+)` 在 `v0.7.7beta` 上捕获 `0.7.7` → tag 路径 `v0.7.7` 404 + 资产名 `onsyuri_v0.7.7_...` 双重错。
  - 历史规律佐证：`v0.7.6beta2`、`v0.7.6beta1` 均为 `beta<数字>` 后缀；裸 `v0.7.6` 也存在。
- **新 checkver（autoupdate 模板不变）**:
  ```json
  "checkver": {
      "github": "https://github.com/YuriSizuku/OnscripterYuri",
      "regex": "v?([\\d.]+(?:beta\\d*)?)"
  }
  ```
  （`v0.7.7beta`→`0.7.7beta`、`v0.7.6beta2`→`0.7.6beta2`、`v0.7.6`→`0.7.6`，三类 tag 全覆盖；$version 带后缀直接落进 URL）
- **验证**: `.../download/v0.7.7beta/onsyuri_v0.7.7beta_x64_win.exe` → 200（3,969,536 字节）、`..._x86_win.exe` → 200（4,011,520 字节）；旧 URL `.../download/v0.7.7/onsyuri_v0.7.7_x86_win.exe` → 404。
- **连带改动**: 无（bin/shortcuts 不变；历史资产名 `amd64_win.exe` 在 0.7.5/0.7.6beta1 也出现过 `arm64_win.exe`，但 x64/x86 主线命名稳定）。

### +13. kotlin-lsp — JetBrains CDN 改址改名（263.4702.0 起）

- **旧模板**（version `262.2310.0`）:
  - 64bit `https://download-cdn.jetbrains.com/kotlin-lsp/$version/kotlin-lsp-$version-win-x64.zip`
  - arm64 `.../kotlin-lsp-$version-win-aarch64.zip`；hash 同名 `.sha256`
- **真实上游状态**（Kotlin/kotlin-lsp latest tag `kotlin-lsp/v263.4702.0`，2026-09-13，零 GitHub 资产，全部下载链接在 release body 里）:
  - Standalone Windows 归档（官方 body 原链）:
    - x64: `https://download.jetbrains.com/language-server/kotlin-server/263.4702.0/kotlin-server-263.4702.0.win.zip`（363,141,017 字节）
    - arm64: `https://download.jetbrains.com/language-server/kotlin-server/263.4702.0/kotlin-server-263.4702.0-aarch64.win.zip`（342,756,883 字节）
  - 三重变化：host `download-cdn.jetbrains.com` → `download.jetbrains.com`；path `/kotlin-lsp/<v>/` → `/language-server/kotlin-server/<v>/`；文件名 `kotlin-lsp-<v>-win-x64.zip` → `kotlin-server-<v>.win.zip`（**点号连接，无 `-win-`**；arm64 是 `-aarch64.win.zip`）。
  - 演进时间线（来自历史 release body）：262.7569.0 时 path 仍 `/kotlin-lsp/` 但 standalone 文件已叫 `kotlin-server-*`；262.9593.0 起 path 改 `/language-server/kotlin-server/`（仍在 -cdn host）；263.4702.0 起 host 去 `-cdn`。
  - **旧 -cdn host 也镜像新 path**：`https://download-cdn.jetbrains.com/language-server/kotlin-server/263.4702.0/kotlin-server-263.4702.0.win.zip` → 200，字节数与主 host 相同（可用作 fallback）。
- **新模板**:
  ```json
  "autoupdate": {
      "architecture": {
          "64bit": {
              "url": "https://download.jetbrains.com/language-server/kotlin-server/$version/kotlin-server-$version.win.zip",
              "hash": {
                  "url": "https://download.jetbrains.com/language-server/kotlin-server/$version/kotlin-server-$version.win.zip.sha256",
                  "regex": "[0-9a-z]{64}"
              }
          },
          "arm64": {
              "url": "https://download.jetbrains.com/language-server/kotlin-server/$version/kotlin-server-$version-aarch64.win.zip",
              "hash": {
                  "url": "https://download.jetbrains.com/language-server/kotlin-server/$version/kotlin-server-$version-aarch64.win.zip.sha256",
                  "regex": "[0-9a-z]{64}"
              }
          }
      }
  }
  ```
- **验证**:
  - 主 URL 200 ×2 + `.sha256` 200（实测内容 `a9b471b1…d0e44 *kotlin-server-263.4702.0.win.zip`、`3bf008d8…e1de *…-aarch64.win.zip`，GNU `*` 二进制模式 —— 现有 regex `[0-9a-z]{64}` 照常命中）。
  - 旧失败 URL `https://download-cdn.jetbrains.com/kotlin-lsp/263.4702.0/kotlin-lsp-263.4702.0-win-x64.zip` → 404（复现）。
  - **内部布局（Range 拉取 zip 中央目录，1054 项清点）**: 根目录含 **`kotlin-lsp.cmd`** ✓（顶层：`bin/ jbr/ lib/ license/ modules/ plugins/ build.txt product-info.json kotlin-lsp.cmd`）—— 与旧归档一致，`"bin": "kotlin-lsp.cmd"`、无 extract_dir 的结构**无需改动**。
- **连带改动**: 无（checkver regex `kotlin-lsp(?:%2F|/)v([\d.]+)` 对 tag `kotlin-lsp/v263.4702.0` 仍捕获 `263.4702.0`，不动）。

---

## 与上轮研究的衔接

- 上轮 `b1-dash-fixes.md` 预警的 "project-86 修好 regex 会跌进 B2 资产坑" 已应验并升级为 **deprecate 候选**（itch.io 迁移，非单纯零资产）。
- 上轮 `dead-upstream.md` 记录的 api.github.com 经 read-tool 匿名 403 问题本轮不适用（eval+urllib 带 UA 匿名 API 全部 200）。

## Caveats / Not verified

- micyou 内层 exe 名（Inno 未解包）——[INFERENCE]，实现时用 innounp 复核；`innosetup: true` 路线本身与 speedynote 一致。
- project-graph `#/app.7z` 对 GPU 安装器的提取布局未解包验证（旧机制同类型安装器有效；实现后应跑一次 `scoop install` 冒烟——本环境无 scoop，留给实现阶段）。
- vibe-around `^v(...)` 加固 regex 仅 API 模式（excavator）安全；tokenless 本地 HTML 模式会失配。
- whoami 上游未回复/无 issue 佐证 goreleaser 失败推断（body 全空 + 前版资产齐全 + repo 活跃是全部证据）；pin 方案在 v1.12.1 发布后需人工放宽 regex。
- JetBrains 未来版本可能继续换 host/path（已在 262.x→263.x 换过三次）；`download-cdn` 镜像新 path 可作容错备选。

## Related files

- 输入：`.trellis/tasks/10-01-fix-excavator-asset-404/research/input-failures.md`（第 26–37 行 + kotlin-lsp）
- manifests：`bucket/{project-86,micyou,snowshot,SymlinkCreator,SunshineGameFinder,sudocode,tagstudio,speedynote,project-graph,vibe-around,whoami,OnscripterYuri,kotlin-lsp}.json`
- 上轮线索：`.trellis/tasks/archive/2026-10/10-01-fix-excavator-checkver/research/{b1-dash-fixes,dead-upstream}.md`
