# Research: B2 asset-404 修复映射 — 第 1–13 项（aionui → kotlin-lsp）

- **Query**: 失败清单第 1–13 项（按 input-failures.md 表格顺序）逐项：读 autoupdate 模板 → GitHub API 查失败 tag/latest 真实资产 → 归纳新命名 → HEAD/下载验证新模板 → 连带改动建议
- **Scope**: mixed（bucket manifests + GitHub API + 资产二进制/zip 结构解析 + JetBrains CDN）
- **Date**: 2026-10-01
- **方法**: python urllib 匿名 GitHub API（带 UA、timeout）；HEAD 验证；对 5 个 zip 做了全量下载 + namelist，对 dango 407MB zip 做了全量下载解析；对 2 个 exe 做了 marker 扫描。GitHub release 下载**不支持 Range**（返回 501 Unsupported client range），需要大文件时只能流式读头或全量下载。

## TL;DR

| # | manifest | 结论 | 新模板要点 | 验证 |
|---|---|---|---|---|
| 1 | aionui | **BLOCKED**（上游连续 8 个 release 零资产） | 无可指资产 | 旧 URL 404 |
| 2 | AssFontSubset | 修复 | `.7z`→`.zip` | 200 |
| 3 | ffmpegfreeui | 修复 | 7z 目录→单 exe，`#/FFmpegFreeUI.exe` 重命名 | 200 |
| 4 | claude-code-haha | 修复 | `_0.6.7_windows_x64_nsis`→`-0.6.7-win-x64` | 200（旧 404） |
| 5 | ccgui | 修复 | `ccgui_`→`CC.GUI_` | 200（旧 404） |
| 6 | beads-viewer | 修复 | 文件名加 `$version_` | 200（旧 404） |
| 7 | dismtools | 修复（checkver 问题） | 模板不变，checkver 正则补 `_updN` | 新 200 / 截断 404 |
| 8 | bongocat | 修复 | `-setup.exe`→`.exe`；**删 32bit** | 200（x86 404） |
| 9 | dango-translator | 修复（连带大） | `zip_$version.zip`→`DangoTranslator-v$version-simple.zip`；删 extract_dir；**shortcuts 改名** | 200 |
| 10 | fleetctl | 修复 | `windows`→`windows_amd64`（url+extract_dir） | 200（旧 404） |
| 11 | collection-manager | 修复 | tag 加 `v` 前缀 | 200（旧 404） |
| 12 | evil-helix | 修复 | `helix-`→`evil-helix-`；**加 extract_dir: helix** | 200（旧 404） |
| 13 | kotlin-lsp | 修复 | 换 CDN：`download.jetbrains.com/language-server/kotlin-server/` | 200×2（旧 404） |

---

## 1. aionui — **BLOCKED**（上游 release 零资产，非模板问题）

- **旧模板**: `https://github.com/iOfficeAI/AionUi/releases/download/v$version/AionUi-$version-win-x64.exe#/dl.7z`（arm64 同型）
- **失败 tag v2.2.2 真实资产**: **零资产**。且 v2.1.56 / v2.1.57 / v2.1.58 / v2.1.59 / v2.1.60 / v2.1.61 / v2.2.1 / v2.2.2 **连续 8 个 release 全部零资产**（releases API 逐个确认，均为非 prerelease；repo 本身活跃，v2.2.2 发布于 2026-09-09）。
- **验证**: `AionUi-2.2.2-win-x64.exe` HEAD **404**；release JSON `assets: []`。
- **新模板**: 无可写——没有任何资产可指。README（repo 根是 `readme.md` 小写）仍指引用户去 Releases 页下载；官网 `www.aionui.com` 是 JS 壳页（1.5KB HTML，无直链），无可编程下载渠道。
- **建议**（主 agent 决策）: 上游发布流水线坏了（大概率 CI 没传资产）。选项：
  - (a) **冻结**：删 `checkver`+`autoupdate`，保持 version 2.1.46（2.1.46 的安装 URL 与 hash 仍有效），excavator 不再排队；待上游恢复资产再恢复。
  - (b) deprecate/remove。repo 本身活跃、只是资产缺失，deprecate 证据不足，倾向 (a)。
- **连带**: arm64 同样失效，一起处理。

## 2. AssFontSubset — 7z → zip（同 tag 资产扩展名变了）

- **旧模板**: `https://github.com/AmusementClub/AssFontSubset/releases/download/v$version/AssFontSubset.Console_v$version_win-x64.7z`
- **失败 tag v2.2.0 真实资产**（Windows 相关）:
  - `AssFontSubset.Console_v2.2.0_win-x64.zip` ← 现在的 64bit 资产
  - `AssFontSubset.Console_v2.2.0_win-arm64.zip`
- **新模板**: `https://github.com/AmusementClub/AssFontSubset/releases/download/v$version/AssFontSubset.Console_v$version_win-x64.zip`
- **验证**: 下载 **200**（4.9MB）；zip 全量解析：**单文件 `AssFontSubset.Console.exe` 在根**，无包装目录。旧 `.7z` URL **404**。
- **连带改动**: 无必改（scoop 原生解 zip；bin `AssFontSubset.Console.exe` 不变，本就无 extract_dir）。
- **附带发现**: repo 已由 `tastysugar/AssFontSubset` 改名/转移到 `AmusementClub/AssFontSubset`（tastysugar API 301 重定向到 repository id 181872306，两者同库同 release）。manifest homepage 仍指 tastysugar（靠重定向活着），建议实现时顺手改成 AmusementClub。可选：新增 arm64 架构（资产存在）。

## 3. ffmpegfreeui — 7z 目录包 → .NET 单文件 exe

- **旧模板**: `https://github.com/Lake1059/FFmpegFreeUI/releases/download/$version/FFmpegFreeUI.ReadyToRun.x64.7z`
- **失败 tag（6.2.x）真实资产**（6.2.28 起所有 release 均为三件套）:
  - `FFmpegFreeUI.x64.exe`（48.6MB）← 64bit 目标
  - `FFmpegFreeUI.arm64.exe`
  - `Updater.exe`
- **新模板**: `https://github.com/Lake1059/FFmpegFreeUI/releases/download/$version/FFmpegFreeUI.x64.exe#/FFmpegFreeUI.exe`
- **验证**: 下载 **200**；二进制 marker 扫描：`mscoree.dll` FOUND（托管 exe）、内嵌 `FFmpegFreeUI.dll` FOUND（单文件 bundle）、`Nullsoft`/`Inno Setup` absent（**不是安装器**）→ 单文件便携 exe。旧 7z URL **404**。
- **连带改动**:
  - **删 `extract_dir: "FFmpegFreeUI ReadyToRun x64"`**（不再是目录包；`#/FFmpegFreeUI.exe` 重命名后 exe 直接落在 $dir）
  - `bin`/`shortcuts`（FFmpegFreeUI.exe）、`pre_install`、`persist: Settings.json` 保留（Settings.json 写在 exe 旁，persist 语义不变）
  - README 明确「运行环境 .NET 10（不自带）」→ 框架依赖；旧 ReadyToRun 7z 同样框架依赖，依赖性质未变，建议加 notes 说明（可选 depends）
  - 可选：arm64 架构 `FFmpegFreeUI.arm64.exe#/FFmpegFreeUI.exe`
  - 发布流水线是 MirrorChyan 镜像（`.github/workflows/mirrorchyan_release.yml`），GitHub 资产就是官方分发物，可放心跟踪

## 4. claude-code-haha — 下划线改连字符、去掉 `_nsis`/`_windows`

- **旧模板**: `https://github.com/NanmiCoder/cc-haha/releases/download/v$version/Claude-Code-Haha_$version_windows_x64_nsis.exe#/nsis.exe`
- **失败 tag v0.6.7 真实资产**（Windows 相关）:
  - `Claude-Code-Haha-0.6.7-win-x64.exe`（213MB）← 64bit 目标
  - `Claude-Code-Haha-0.6.7-win-arm64.exe`
  - （另有 `latest.yml`——electron-builder NSIS 全家桶，佐证仍是 NSIS 安装器）
- **新模板**: `https://github.com/NanmiCoder/cc-haha/releases/download/v$version/Claude-Code-Haha-$version-win-x64.exe#/nsis.exe`
- **验证**: 新 URL **200**；旧 URL（`Claude-Code-Haha_0.6.7_windows_x64_nsis.exe`）**404**。
- **连带改动**: 无必改。仍是 electron NSIS exe（`latest.yml` 存在；electron NSIS 可被 7z 解包），`installer.script`（7z x + 清 .nsi/$*）、bin `claude-sidecar.exe`、shortcut `claude-code-desktop.exe` 全部保留。
- **可选**: 新增 arm64 架构（`Claude-Code-Haha-$version-win-arm64.exe#/nsis.exe`，同脚本）。

## 5. ccgui — Windows 资产前缀 `ccgui_` → `CC.GUI_`

- **旧模板**: `https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases/download/v$version/ccgui_$version_x64-setup.exe#/dl.7z`
- **失败 tag v1.1.0 真实资产**（Windows 相关）:
  - `CC.GUI_1.1.0_x64-setup.exe`（14.9MB）← 目标（+ `.sig`）
  - （mac 资产仍叫 `ccgui_1.1.0_x86_64.dmg`——只有 Windows 改了大写）
- **新模板**: `https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases/download/v$version/CC.GUI_$version_x64-setup.exe#/dl.7z`
- **验证**: 新 URL **200**；旧 URL（`ccgui_1.1.0_x64-setup.exe`）**404**。
- **连带改动**: 无必改（仍是 NSIS setup；`#/dl.7z` + `pre_install` 清 `$*`/`Uninstall*` 保留；shortcut `cc-gui.exe` 不变；tauri 项目带 `latest.json`）。

## 6. beads-viewer — 资产文件名加版本号

- **旧模板**: `https://github.com/Dicklesworthstone/beads_viewer/releases/download/v$version/bv_windows_amd64.zip`
- **失败 tag v0.25.2 真实资产**（Windows 相关）:
  - `bv_0.25.2_windows_amd64.zip`（14.8MB）← 目标
  - `bv_0.25.2_windows_amd64.zip.sha256`、`SHA256SUMS`、`checksums.txt`
- **新模板**: `https://github.com/Dicklesworthstone/beads_viewer/releases/download/v$version/bv_$version_windows_amd64.zip`
- **验证**: 下载 **200**；zip 全量解析：**扁平结构**，`bv.exe` + CHANGELOG/LICENSE/README 在根，无包装目录 → bin `bv.exe` 不变、无 extract_dir。旧 URL **404**。
- **连带改动**: 无必改。
- **可选 hash autoupdate**: `{"url": ".../bv_$version_windows_amd64.zip.sha256", "regex": "([0-9a-f]{64})"}`（sidecar 存在已验证，内容格式未读——实现时确认）。

## 7. dismtools — 模板没错，是 checkver 默认正则截断 `_upd1`

- **旧模板**: `https://github.com/CodingWonders/DISMTools/releases/download/v$version/DISMTools.zip`（**模板本身正确，不改**）
- **失败根因**: 最新 tag `v0.8.1_upd1`（2026-09-26 发布）下 checkver `"github"` 走默认正则 `(?:v|V)?([\d.-]+)`，字符类不含 `_`，捕获成 `0.8.1` → autoupdate 填出 `.../download/v0.8.1/DISMTools.zip` → **404**（tag 实际是 `v0.8.1_upd1`）。
- **v0.8.1_upd1 真实资产**: `DISMTools.zip`（85.8MB）✓、`dt_setup.exe`。
- **修复**（改 checkver，不改 autoupdate）:

```json
"checkver": {
    "github": "https://github.com/CodingWonders/DISMTools",
    "regex": "v?([\\d.]+(?:_upd\\d+)?)"
}
```

- **验证**: `v0.8.1_upd1/DISMTools.zip` HEAD **200**；`v0.8.1/DISMTools.zip` HEAD **404**（根因实锤）。version 将从 `0.7.1_upd1` → `0.8.1_upd1`（同族格式，历史 version 本就带 `_updN`）。
- **连带改动**: 无（shortcuts/bin/hash 机制不变）。

## 8. bongocat — x64 去掉 `-setup`，x86 资产消失

- **旧模板**: 64bit `.../v$version/BongoCat_$version_x64-setup.exe#app.7z`；32bit `.../v$version/BongoCat_$version_x86-setup.exe#app.7z`
- **失败 tag v2.0.1 真实资产**（Windows 全部）:
  - `BongoCat_2.0.1_x64.exe`（10.2MB）← 唯一 Windows 资产
  - （+ `.exe.sig`、`latest.json`、mac 的 dmg/app.tar.gz）
- **新模板（64bit）**: `https://github.com/ayangweb/BongoCat/releases/download/v$version/BongoCat_$version_x64.exe#app.7z`
- **验证**: 新 exe 下载 **200**；marker 扫描 `Nullsoft` FOUND → **仍是 NSIS**（`#app.7z` 提取 + `$PLUGINSDIR` 搬移脚本语义沿用 1.1.0 的可用流程）；`BongoCat_2.0.1_x86-setup.exe` HEAD **404**。
- **连带改动**: **删除 32bit 架构块**（x86 资产已消失，无 arm64 Windows 资产）。autoupdate 里 32bit 模板一并删。shortcuts `bongo-cat.exe`、pre_install 保留。

## 9. dango-translator — 资产整体改名 + zip 结构扁平化 + 主程序 exe 改名（连带改动最大）

- **旧模板**: `https://github.com/PantsuDango/Dango-Translator/releases/download/Ver.$version/zip_$version.zip`
- **失败 tag `Ver.6.3.3` 真实资产**（全部）:
  - `DangoTranslator-v6.3.3-all.zip`（1.1GB，完整离线包）
  - `DangoTranslator-v6.3.3-simple.zip`（407MB，精简包）← 推荐
  - `DangoTranslator-v6.3.3-all.exe` / `DangoTranslator-v6.3.3-simple.exe`（安装器，不用）
- **新模板**: `https://github.com/PantsuDango/Dango-Translator/releases/download/Ver.$version/DangoTranslator-v$version-simple.zip`
- **验证**: 下载 **200**（407MB 全量下载解析）。
- **连带改动（必改）**——simple.zip 全量 namelist（311 条）实测：
  - **删 `extract_dir: "DangoTranslator"`**：新 zip 扁平无包装目录（顶层直接是 `DangoTranslator.exe`、`Qt5*.dll`、`config/`、`ppc/`、`rdr/`、`2.3.0.2/` 等；`2.3.0.2/` 只是内部数据子目录）
  - **主程序改名**：根目录是 `DangoTranslator.exe`（不再是 `团子翻译器.exe`）→ shortcuts 两处 `团子翻译器.exe` 改为 `DangoTranslator.exe`
  - Qt5 运行库自带（libstdc++/Qt5Core 等 in-box）
- checkver 侧 `Ver\.?([\d.]+)`（上轮已修）与模板 `Ver.$version` 搭配 `Ver.6.3.3` ✓ 无需动。
- **备注**: `-all.zip` 与 simple 布局同源（推测，未下载验证）；如需离线模型全量可换 all，extract_dir/shortcuts 结论同样适用。

## 10. fleetctl — `windows` → `windows_amd64`（url + extract_dir 一起）

- **旧模板**: `.../download/fleet-v$version/fleetctl_v$version_windows.zip`，`extract_dir: fleetctl_v$version_windows`
- **失败 tag `fleet-v4.92.2` 真实资产**（Windows 相关）:
  - `fleetctl_v4.92.2_windows_amd64.zip`（15.8MB）← 目标
  - `fleetctl_v4.92.2_windows_arm64.zip` / `_amd64.tar.gz` / `.msi`、`checksums.txt`
- **新模板**: `https://github.com/fleetdm/fleet/releases/download/fleet-v$version/fleetctl_v$version_windows_amd64.zip`，`extract_dir: fleetctl_v$version_windows_amd64`
- **验证**: 下载 **200**；zip 全量解析：顶层目录 **`fleetctl_v4.92.2_windows_amd64/`**（内含 `fleetctl.exe` + CHANGELOG/LICENSE/README）→ extract_dir 换成 `fleetctl_v$version_windows_amd64` 后 bin `fleetctl.exe` 不变。旧 `fleetctl_v4.92.2_windows.zip` **404**。
- **连带改动**: extract_dir 同步（已含在上）；checkver `fleet-v([\d.]+)` 不变。
- **可选 hash**: `.../download/fleet-v$version/checksums.txt` 存在（内部格式未验证，实现时再定 regex）。

## 11. collection-manager — 上游 tag 加了 `v` 前缀

- **旧模板**: `https://github.com/Piotrekol/CollectionManager/releases/download/$version/CollectionManagerSetup.exe`
- **失败 tag `v1.3.0` 真实资产**（全部）:
  - `CollectionManagerSetup.exe`（6.6MB）← 资产名没变！
  - `CollectionManager-WinForms.zip`、`CollectionManager-CLI.zip`（新增的便携 zip）
- **根因**: 1.2.2 时代 tag 是裸 `1.2.2`，1.3.0 起 tag 变成 `v1.3.0`；模板缺 `v` → `.../download/1.3.0/...` → 404。checkver `"github"` 默认正则会剥掉 `v`（version=1.3.0），所以 version 侧无感。
- **新模板**: `https://github.com/Piotrekol/CollectionManager/releases/download/v$version/CollectionManagerSetup.exe`
- **验证**: 新 URL **200**；旧形态（无 v）**404**。
- **连带改动**: 无必改（`innosetup: true`、bin/shortcut 不变）。
- **可选**: 上游新增便携包 `CollectionManager-WinForms.zip`（内含 exe 名未验证），比 innosetup 更 scoop 友好，可作后续优化，本次不动。

## 12. evil-helix — 资产前缀 `helix-` → `evil-helix-`，且 zip 多了 `helix/` 包装层

- **旧模板**: `https://github.com/usagi-flow/evil-helix/releases/download/release-$version/helix-amd64-windows.zip`
- **失败 tag `release-20250915` 真实资产**（Windows 相关）:
  - `evil-helix-amd64-windows.zip`（29.5MB）← 目标
- **新模板**: `https://github.com/usagi-flow/evil-helix/releases/download/release-$version/evil-helix-amd64-windows.zip`
- **验证**: 下载 **200**；zip 全量解析（1230 条）：**顶层是 `helix/` 包装目录**，内含 `helix/hx.exe`、`helix/runtime/queries`、`helix/runtime/grammars/*.dll` 等。旧 `helix-amd64-windows.zip` **404**。
- **连带改动（必改）**: **加 `"extract_dir": "helix"`**——否则 zip 解出 `$dir/helix/...`，bin `hx.exe` 找不到；解包到根后 `hx.exe` 与 `runtime/` 相邻，hx 按可执行文件相对路径找 runtime ✓。checkver `release-(\d+)` 不变。

## 13. kotlin-lsp — JetBrains 换分发渠道（CDN 路径 + 产物改名 kotlin-lsp→kotlin-server）

- **旧模板**:
  - 64bit: `https://download-cdn.jetbrains.com/kotlin-lsp/$version/kotlin-lsp-$version-win-x64.zip`
  - arm64: `https://download-cdn.jetbrains.com/kotlin-lsp/$version/kotlin-lsp-$version-win-aarch64.zip`
  - hash: 各自 `+.sha256`，regex `[0-9a-z]{64}`
- **失败版本 263.4702.0 现状**:
  - 旧 CDN URL **404**（本机 HEAD 实测；上轮研究结论一致）
  - GitHub release `kotlin-lsp/v263.4702.0` **零资产**（GitHub 从不挂资产，纯 changelog）
  - release body 官方给出新渠道（Standalone Kotlin LSP Archive，供非 VS Code 编辑器）：`https://download.jetbrains.com/language-server/kotlin-server/<ver>/kotlin-server-<ver>[.win|-aarch64.win].zip` + `.sha256` sidecar
- **新模板**:
  - 64bit: `https://download.jetbrains.com/language-server/kotlin-server/$version/kotlin-server-$version.win.zip`
  - arm64: `https://download.jetbrains.com/language-server/kotlin-server/$version/kotlin-server-$version-aarch64.win.zip`
  - hash: 各自 `+.sha256`，regex 建议 `([0-9a-f]{64})`（现 `[0-9a-z]{64}` 无捕获组也能整段匹配，可不改）
- **验证**:
  - x64 zip **200**（363MB）；zip 尾部 Range 解析（JetBrains CDN 支持 Range，1065 条）：顶层 `bin/`、`jbr/`、`lib/`、`modules/`、`plugins/`、**`kotlin-lsp.cmd` 在根** → bin `"kotlin-lsp.cmd"` **不用改**，无需 extract_dir
  - arm64 zip **200**（342MB）
  - sha256 sidecar GET 200，内容 `<64hex> *<filename>` 格式 ✓
  - 实测哈希（实现者可直接用）：x64 `a9b471b16025b1bfb3b0a097862580abb40e3c35406c44242c18b1d70f5d0e44`、arm64 `3bf008d8c94fa70eb13fc998eaa42f29b9d13f368984d4cec46277808f94e1de`
- **连带改动**: 无结构改动（bin/extract 不变）。checkver `kotlin-lsp(?:%2F|/)v([\d.]+)` 不变。注意：单包 363MB（内嵌 JBR），体积大是上游分发现状；产物已更名 kotlin-server，description 可选顺手更新。

---

## 上轮研究线索复用情况

- dango-translator 6.x 资产名（a2-regex-fixes.md §2.1）→ 本轮全量下载确认布局 + exe 改名（新增发现：扁平化 + `DangoTranslator.exe`）
- kotlin-lsp CDN 404（a2-regex-fixes.md §2.7）→ 本轮从 release body 找到新渠道并验证
- fleetctl tag 格式（a2-regex-fixes.md §2.8）→ 复用，资产重命名是本轮新发现

## Caveats / Not verified

- **aionui**：无任何 Windows 资产可指（8 个连续 release 零资产），官网是 JS 壳页；只能冻结或移除，等上游恢复。
- dango `-all.zip` 布局未下载验证（按同源流水线推测与 simple 一致）。
- beads-viewer / fleetctl 的 `.sha256`/`checksums.txt` sidecar 内部格式未读取，hash autoupdate 为可选项。
- claude-code-haha 新 exe 未做 marker 扫描（213MB 未下载）；「仍是 electron NSIS」依据是 `latest.yml` 存在 + electron-builder 资产全家桶命名 + 旧版同机制可用。
- collection-manager 的 `CollectionManager-WinForms.zip` 内部结构未验证。
- ffmpegfreeui 单 exe 运行时依赖系统 .NET 10（README 明示）；若目标用户没装运行时会启动失败——旧 ReadyToRun 包同病，非本次回归，建议实现时加 notes。

## Related files

- 输入清单：`research/input-failures.md`（第 1–13 项 = aionui…kotlin-lsp，表格顺序）
- manifests：`bucket/{aionui,AssFontSubset,ffmpegfreeui,claude-code-haha,ccgui,beads-viewer,dismtools,bongocat,dango-translator,fleetctl,collection-manager,evil-helix,kotlin-lsp}.json`
- 上轮研究：`.trellis/tasks/archive/2026-10/10-01-fix-excavator-checkver/research/{a2-regex-fixes,b1-dash-fixes,dead-upstream}.md`
