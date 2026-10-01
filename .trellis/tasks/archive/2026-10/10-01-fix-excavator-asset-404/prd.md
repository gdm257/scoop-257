# PRD: 修复 excavator 自动更新 B2 类失败（资产 URL 404）

## 背景

excavator run #36848065752（2026-10-01）：37 个 manifest checkver 成功拿到新版本号，但 autoupdate 资产 URL 404。上轮（10-01-fix-excavator-checkver）修复的 checkver/regex 类工作正常（pi、wsl-centos-8、pororoca、skillshare、octopus-257 等已自动更新落地），本轮处理当时明确遗留的 B2 类。

根因分布（研究见 `research/asset-map-{a,b,c}.md`，全部经 HEAD/下载实测验证）：

- 上游资产改名/改扩展名/去版本号（约 20 项）
- 上游 tag 改格式，checkver 默认正则截断后缀（dismtools `_upd1`、inkeys 尾缀 `a`、OnscripterYuri `beta`、snowshot `_snow-shot`）
- 上游部分发布（KataGo：补丁版只编部分后端，5 个 manifest 需资产锚定 checkver）
- 上游发布渠道迁移（project-86 → itch.io、sudocode → npm、lazyjj → cargo、kotlin-lsp → JetBrains 新 CDN）
- 上游发布故障（aionui 连续 8 release 零资产、whoami v1.12.0 零资产）
- atom feed 被草稿 release 污染（pdf-guru）

## 范围

`bucket/` 下 37 个 manifest（清单见 `research/input-failures.md`）。不新增 manifest，不改 scripts/CI。

## 方案

### A. 模板修复（20 项，新 URL 全部已 HEAD 200 验证）

| manifest | 修复 | 连带改动 |
|---|---|---|
| AssFontSubset | `.7z`→`.zip` | homepage 改 AmusementClub |
| ffmpegfreeui | 7z 目录包→单 exe，`#/FFmpegFreeUI.exe` | 删 extract_dir |
| claude-code-haha | 资产名 `_v_windows_x64_nsis`→`-v-win-x64` | 无 |
| ccgui | `ccgui_`→`CC.GUI_` | 无 |
| beads-viewer | 文件名加 `$version_` | 无 |
| bongocat | `-setup.exe`→`.exe` | **删 32bit 块**（x86 资产消失） |
| dango-translator | `zip_$version.zip`→`DangoTranslator-v$version-simple.zip` | 删 extract_dir；shortcuts `团子翻译器.exe`→`DangoTranslator.exe` |
| fleetctl | `windows`→`windows_amd64` | extract_dir 同步 |
| collection-manager | tag 加 `v` 前缀 | 无 |
| evil-helix | `helix-`→`evil-helix-` | **加 extract_dir: helix** |
| kotlin-lsp | 换 JetBrains 新 CDN（host/path/文件名三重变化） | bin `kotlin-lsp.cmd` 不变 |
| hatch | 资产名去版本号 | **删 pre_install 的 Move-Item** |
| keploy | `.tar.gz`→裸 exe + `#/keploy.exe` | **删 arm64 块** |
| pachi | `win64.zip`→`win64-avx.zip` | **删 32bit 块** |
| okegui | `.zip`→`.7z` | 无 |
| micyou | 便携 zip→Inno 安装器 | 删 extract_dir；加 `innosetup: true` |
| SymlinkCreator | 文件名去版本号、按架构拆分→`Symlink.Creator.x64.zip` | 无 |
| SunshineGameFinder | 裸 exe→版本化 zip | 删 `#/…exe` 后缀 |
| tagstudio | 资产名加 `_v$version` | 无 |
| speedynote | 32bit `_x86`→`_x86_32` | 无 |
| project-graph | plain→`_x64-setup-gpu.exe` | 无 |
| vibe-around | `win-$version-portable`→`Windows-x64-Portable-$version` | checkver 加 `^v([\d.]+)` 防 va-v CLI tag 干扰 |

### B. 纯 checkver 修复（3 项，autoupdate 模板不变）

- dismtools：regex `v?([\d.]+(?:_upd\d+)?)`（默认正则截断 `_upd1`）
- inkeys：regex `tag/(\d+[a-z]?)`（截断尾缀 `a`）
- OnscripterYuri：regex `v?([\d.]+(?:beta\d*)?)`（截断 `beta`）

### C. KataGo 家族资产锚定（5 项）

上游部分发布模式：v1.18.2 只发 CUDA，opencl/eigen/trt 最新资产在 v1.18.1。解法 = checkver 换「API + 反向引用正则」资产锚定（本桶 veyon.json 先例，live 实测）：

- katago / katago-opencl：opencl 锚，URL 模板不变
- katago-eigen：eigen 锚，URL 模板不变
- katago-tensorrt：trt10.2.0 锚；删 trt8.6.1 两 URL，加 trt10.16.1-cuda13.2；修既存 bin 路径错位（10.9.0-bs50 错指 10.2.0-bs50）
- katago-full：opencl 锚；删 trt8.6.1 两 URL（最小 16 URL 方案，不扩展 rocm/openvino）
- pdf-guru：资产锚定自愈（atom 被 draft release 污染，锚定解析回 1.0.12 = 当前版本）

代价：每次 excavator run 新增约 6 次匿名 GitHub API 调用（5 katago + pdf-guru），60/h 限额内可控。

### D. 上游故障处置（用户已确认 2026-10-01：lazyjj / whoami 本轮不动，其余按建议执行）

| manifest | 现状 | 处置 |
|---|---|---|
| project-86 | 官方迁 itch.io，GitHub 不再发资产 | **deprecate → `deprecated/`** |
| sudocode | 发行迁 npm（1.2.0），GitHub 零资产 6.5 月 | **deprecate → `deprecated/`** |
| aionui | repo 活跃但连续 8 release 零资产（疑似 CI 故障） | **冻结**：删 checkver/autoupdate，保留 2.1.46 可安装态 |
| lazyjj | v0.6.x 明示只改 Cargo.toml，二进制停在 0.5.0 | **不动**（本轮不处理，excavator 暂留 404 噪音） |
| whoami | v1.12.0 零资产（疑似 goreleaser 上传失败） | **不动**（同上，等上游带资产发新版后自愈） |

（deprecate 先例：上轮 chrome-plus/WinDeckHelper 移入 `deprecated/`，纯 rename 不删除。）

## 验收标准

1. 35 个失败项处置到位（37 项中 lazyjj/whoami 经用户确认本轮不动）：修复后新 URL 逐项 HEAD 200；deprecate/冻结项不再进 excavator 失败队列
2. 连带改动完整：extract_dir/bins/shortcuts/pre_install 与新包结构一致（研究已逐项实测 zip/7z 内部结构）
3. manifest JSON 合法、UTF-8、LF；命名组 regex 兼容 scoop（API 模式语义）
4. 不引入新失败：修复项 checkver 结果与 $version 语义自洽（特别是 tag 后缀类）

## 非目标

- 不跑 `scoop download`/`scoop install`（环境无 scoop，结构已通过下载解析验证）
- 不新增 rocm/openvino/directml/arm64 等新变体/架构
- 不改 veyon 等既有 API checkver
- sudocode 不改写为 npm 型 manifest

## 研究索引

- `research/input-failures.md` — 37 项失败清单（manifest/repo/资产）
- `research/asset-map-a.md` — 第 1–13 项明细（aionui→kotlin-lsp）
- `research/asset-map-b.md` — 第 14–26 项明细 + KataGo 家族机制分析
- `research/asset-map-c.md` — 第 26–37 项明细 + kotlin-lsp CDN 时间线
