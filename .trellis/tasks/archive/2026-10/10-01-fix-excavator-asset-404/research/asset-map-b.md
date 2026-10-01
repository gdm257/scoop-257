# Research: B2 asset-404 修复映射 — 第 14–26 项（inkeys → project-86）

- **Query**: 失败清单第 14–26 项（按 input-failures.md 表格顺序，第 20–32 行）逐项：读 autoupdate 模板与 checkver → GitHub API 查失败 tag/latest 真实资产 → 归纳新命名 → HEAD/下载验证新模板 → 连带改动建议
- **Scope**: mixed（bucket manifests + GitHub API + zip/7z 内部结构解析）
- **Date**: 2026-10-01
- **方法**: python urllib 匿名 GitHub API（带 UA、timeout）；HEAD 验证（跟随 302 到 objects.githubusercontent.com，不计 API 限额）；hatch zip（1.6MB）、pachi zip（63MB）、okegui 7z（180MB）全量下载后解析内部目录结构（7z 用本机 `scoop/apps/7zip/current/7z.exe` 列表）。KataGo v1.18.2 资产经 `/releases/{id}/assets?per_page=100` 确认拿全（24 < 100，单页完整）。
- **本篇核心机制发现**: KataGo 采用「**部分发布**」模式（补丁版只重编有变化的后端，v1.17.2 只发 TRT、v1.18.2 只发 CUDA），因此 `checkver: github` 拿到的最新 tag 对多数后端**没有资产**。不是砍后端，不能 deprecate。统一解法 = **资产锚定 checkver**（API + 反向引用正则，本桶已有先例 `bucket/veyon.json`）。

## TL;DR

| # | manifest | 结论 | 新模板/checkver 要点 | 验证 |
|---|---|---|---|---|
| 14 | inkeys | 修复（checkver 截断） | 模板不变；checkver 加 `tag/(\d+[a-z]?)` 捕获尾缀 `a` | 新 200×3 / 截断 404 |
| 15 | katago-full | 修复 | **资产锚定 checkver**（opencl 锚）→ 1.18.1；删 trt8.6.1 两 URL；可选新增 10 个变体 | 1.18.1 目标 URL 200 |
| 16 | hatch | 修复 | 资产名去掉版本号 `hatch-x86_64-pc-windows-msvc.zip`；**删 pre_install** | 200（旧 404） |
| 17 | katago-opencl | 修复 | 资产锚定 checkver → 1.18.1，URL 模板不变 | 200×2 |
| 18 | lazyjj | **BLOCKED/决策** | 上游 v0.6.x 零资产（不发二进制了）；冻结 0.5.0 或 deprecate | v0.6.1 404 / v0.5.0 200 |
| 19 | katago | 修复 | 资产锚定 checkver → 1.18.1，URL 模板不变 | 200 |
| 20 | katago-eigen | 修复 | 资产锚定 checkver → 1.18.1，URL 模板不变 | 200×4 |
| 21 | pdf-guru | 修复（checkver 污染） | **atom 被 draft release 污染**；资产锚定 checkver → 1.0.12（=现版本，不再触发更新） | v1.0.12 200 / 1.1.3 404 |
| 22 | keploy | 修复 | 资产去掉 `.tar.gz` → 裸 exe，`#/keploy.exe` 重命名；**删 arm64 架构** | 200（旧 404，arm64 404） |
| 23 | katago-tensorrt | 修复 | 资产锚定 checkver → 1.18.1；trt8.6.1 → trt10.16.1-cuda13.2；修 bin 既存错位 bug | 200×6 |
| 24 | pachi | 修复 | `win64.zip`→`win64-avx.zip`（12.86 起）；**删 32bit**；extract_dir 不变 | 200×2（旧 404） |
| 25 | okegui | 修复 | `.zip`→`.7z`；extract_dir `OKEGui` 不变 | 200（旧 404） |
| 26 | project-86 | **deprecate 候选/决策** | 上游迁 itch.io，GitHub 不再发资产；备选资产锚定 → v2.0.0-alpha.1 | alpha.2 404 / alpha.1 200 |

---

## KataGo 家族（14–26 项中的 5 个：katago / katago-full / katago-opencl / katago-eigen / katago-tensorrt）

### 根因：部分发布（partial release），不是砍后端

- **v1.18.2 真实资产（24 个，已确认拿全）**: 只有 CUDA 变体 — `cuda12.1-cudnn8.9.7`、`cuda12.1-cudnn9.8.0`、`cuda12.5-cudnn8.9.7`、`cuda12.5-cudnn9.8.0`、`cuda12.8-cudnn9.8.0`、`cuda13.2-cudnn9.24.0`，各 × linux/windows × (plain/+bs50) = 24。**无 opencl / eigen / eigenavx2 / trt / onnx / rocm**。
- **release notes 原文**（v1.18.2）: "This is a quick minor optimization release for the CUDA backend… **For all other backends (AMD GPUs, etc) see the prior release v1.18.1**"；TensorRT 段落: "**See the prior release v1.18.1 for prebuilt exes**"、"TensorRT versions older than 10 are not supported"。
- **先例**: v1.17.2 同样是部分发布（12 资产，仅 trt10.2.0/trt10.9.0/trt10.16.1 的 linux+windows plain/bs50）；v1.18.1 是完整发布（66 资产，18 个 windows 变体 × 2）。
- **结论**: opencl/eigen/trt 的最新资产 = **v1.18.1**（HEAD 全 200），CUDA 最新 = v1.18.2。`checkver: "github"`（releases.atom 默认正则 `tag/([\d.]+)`）只会拿到 1.18.2，对非 CUDA 后端必然 404，且每次部分发布都会复发。

### 统一解法：资产锚定 checkver（已实测）

把 `"checkver": "github"` 换成「API + 反向引用正则」，取**第一个包含目标资产的 release**：

```json
"checkver": {
    "url": "https://api.github.com/repos/lightvector/KataGo/releases?per_page=100",
    "regex": "releases/download/v([\\d.]+)/katago-v\\1-opencl-windows-x64\\.zip"
}
```

- 机制: `/releases` 按 created_at 倒序；`\1` 反向引用保证 tag 版本与资产内嵌版本一致；无该资产的 release（v1.18.2）不产生匹配，自动跳过。scoop checkver 用 .NET `[regex]::Match`，反向引用可用；本桶 `bucket/veyon.json`（`api.github.com` + regex）是现成先例。
- **实测（2026-10-01，live API）**: opencl 锚→`1.18.1`；eigen 锚→`1.18.1`；trt10.2.0/trt10.9.0/trt10.16.1 锚→`1.18.1`；cuda12.8 锚→`1.18.2`。
- 限额: 匿名 60 req/h；本 bucket 每次 checkver run 新增 ~7 个 API 调用（5 个 katago + pdf-guru + 既有 veyon），可控。
- 版本字段从 `1.18.1`/`1.16.5` → 锚定解析值（当前均 = `1.18.1`，katago-full 亦然，因 opencl 只出现在完整发布里——"最新含 opencl 的 release" = 最新完整版，v1.17.2 这种 TRT-only 补丁被正确跳过）。

### v1.18.1 完整 windows 资产清单（供 katago-full / katago-tensorrt 重建 URL 集合）

| 后端变体 | plain | +bs50 | HEAD |
|---|---|---|---|
| opencl | ✓ | ✓ | 200/200 |
| eigen | ✓ | ✓ | 200/200 |
| eigenavx2 | ✓ | ✓ | 200/200 |
| cuda12.1-cudnn8.9.7 | ✓ | ✓ | 200/200 |
| cuda12.1-cudnn9.8.0（新） | ✓ | ✓ | —（API 确认存在） |
| cuda12.5-cudnn8.9.7 | ✓ | ✓ | 200/200 |
| cuda12.5-cudnn9.8.0（新） | ✓ | ✓ | — |
| cuda12.8-cudnn9.8.0 | ✓ | ✓ | 200/200 |
| cuda13.2-cudnn9.24.0（新） | ✓ | ✓ | —（v1.18.2 同名 200×2） |
| trt10.2.0-cuda12.5 | ✓ | ✓ | 200/200 |
| trt10.9.0-cuda12.8 | ✓ | ✓ | 200/200 |
| trt10.16.1-cuda13.2（新，替代 trt8） | ✓ | ✓ | 200/200 |
| rocm7.13-gfx103X / gfx110X / gfx1151 / gfx120X（新，AMD） | ✓ | ✓ | — |
| onnx-openvino2026.2.1（新） | ✓ | ✓ | — |
| onnx1.24.4-directml（新） | ✓ | ✓ | — |

（v1.18.2 的 6 个 CUDA 变体 plain+bs50 windows 已全部 HEAD 200。）

---

## 14. inkeys — checkver 正则截断尾缀（模板本身没错）

- **旧模板**: `https://github.com/Alan-CRL/Inkeys/releases/download/$version/Inkeys$version-x64.zip`（x86/arm64 同型）
- **失败资产**: `Inkeys20260713-x86.zip` ← checkver 返回了 `20260713`，而真实 tag 是 `20260713a`
- **根因**: `"checkver": {"github": "..."}` 无自定义 regex → scoop 默认 `tag/([\d.]+)` 在 `20260713a` 上**截断尾缀 a**。已实测复现：默认正则→`20260713`（404），自定义→`20260713a`（200）。
- **修复**（checkver 加一行 regex，模板/extract_dir/shortcuts 全不变）:

```json
"checkver": {
    "github": "https://github.com/Alan-CRL/Inkeys",
    "regex": "tag/(\\d+[a-z]?)"
}
```

- **验证**: `20260713a` tag 下 x64/x86/arm64 三资产 HEAD **200**（19.4/18.8/18.8MB）；无-`a` 版本 404。atom 全部 10 个近期 tag 均带 `a` 尾缀，正则稳定。本桶 `project-86.json` 已用同型 `{"github":…, "regex":…}`，格式有先例。
- **版本**: `20260713a`（= 当前 manifest 版本，修好后 checkver 结果与版本一致，不再触发失败的 autoupdate）。

## 15. katago-full — 资产锚定 + URL 集合收缩（可选扩展）

- **旧模板**: 18 URL（opencl、cuda12.1/12.5(cudnn8.9.7)、cuda12.8(cudnn9.8.0)、trt10.2.0、trt10.9.0、**trt8.6.1**、eigen、eigenavx2 × plain/bs50），锚 `v$version`
- **修复**: checkver 换 **opencl 锚定**（见家族总节，实测→`1.18.1`）。URL 集合（最小改动方案）= 旧 9 后端删 trt8.6.1 → **8 后端 × 2 = 16 URL**，全部指向 `v1.18.1`：

```
https://github.com/lightvector/KataGo/releases/download/v$version/katago-v$version-{opencl|cuda12.1-cudnn8.9.7|cuda12.5-cudnn8.9.7|cuda12.8-cudnn9.8.0|trt10.2.0-cuda12.5|trt10.9.0-cuda12.8|eigen|eigenavx2}-windows-x64{+bs50}.zip
```

- **连带改动**: `extract_to` 与 `bin` 各删 2 条 trt8 条目（`katago-tensorrt8(-bs50)`）；其余 8 后端条目不变。
- **可选扩展**（主 agent 决策，资产均存在于 v1.18.1，见上表）: 新增 cuda12.1/12.5-cudnn9.8.0、cuda13.2-cudnn9.24.0、trt10.16.1-cuda13.2、rocm7.13×4（AMD GPU）、onnx-openvino、onnx-directml。openvino/directml 是 v1.18.x 官方推荐的 NVIDIA 以外首选，加入可显著提升 manifest 价值，但 URL/extract_to/bin 全要配套加。
- **验证**: 16 URL 中 18 个 v1.18.1 目标已 HEAD 全 200（见上表；16 URL 是其子集）。

## 16. hatch — 资产名去掉版本号 + 删 pre_install

- **旧模板**: `https://github.com/pypa/hatch/releases/download/hatch-v$version/hatch-$version-x86_64-pc-windows-msvc.zip`
- **失败 tag hatch-v1.18.1 真实资产**（17 个，windows 相关）: `hatch-x86_64-pc-windows-msvc.zip` ← 目标（**无版本号**）；`hatch-dist-x86_64-pc-windows-msvc.tar.gz`、`hatch-i686-pc-windows-msvc.zip`、`hatch-x64.msi`、`hatch-universal.exe` 等。v1.18.0/v1.18.1 命名一致，非一次性。
- **新模板**: `https://github.com/pypa/hatch/releases/download/hatch-v$version/hatch-x86_64-pc-windows-msvc.zip`
- **验证**: 新 URL HEAD **200**（1.65MB）；旧 URL **404**。全量下载解析：**zip 内是单个 `hatch.exe`**（旧版是 `hatch-$version-x86_64-pc-windows-msvc.exe`）。
- **连带改动（必改）**: **删除 `pre_install` 的 `Move-Item hatch-$version-…exe → hatch.exe`** —— 版本化 exe 不复存在，pre_install 会直接报错。`bin: "hatch.exe"` 保持；notes（pyapp 运行时下载）保持。
- **checkver 不变**: `{"github": …, "regex": "hatch-v([\\d.]+)"}` 正则扫描整个 atom 内容，正确跳过穿插的 hatchling-v* release（最新 5 个 release 中 3 个是 hatchling），实测目标 = `1.18.1`。

## 17. katago-opencl — 模板不变，换锚定 checkver

- checkver 换 opencl 锚（实测→`1.18.1`）；2 个 URL 模板原样保留，版本字段 `1.18.1`→ 保持 `1.18.1`（manifest 已在 1.18.1，只是 excavator 被最新 tag 1.18.2 误导）。
- **验证**: v1.18.1 opencl plain/bs50 HEAD **200×2**；v1.18.2 opencl **404**（即本次失败）。

## 18. lazyjj — **BLOCKED/决策**：上游不再附二进制

- **旧模板**: `https://github.com/Cretezy/lazyjj/releases/download/v$version/lazyjj-v$version-x86_64-pc-windows-msvc.zip`
- **真实资产**: `v0.6.1`（2025-09-10）**零资产**；`v0.6.0`（2025-09-10）零资产；最后带二进制的是 `v0.5.0`（2025-02-15，含 windows zip）。release notes 原文（v0.6.1）: "**This release is created only to update version in Cargo.toml**." —— 上游明确不再发 release 二进制，且已持续 1 年+无新 release。
- **验证**: v0.6.1 模板 URL **404**（本次失败）；v0.5.0 pinned URL **200**。
- **选项**（主 agent 决策）:
  - (a) **deprecate 候选**: 上游分发转向 cargo/源码，GitHub 二进制已死 1 年。
  - (b) **冻结在 0.5.0**: checkver 换资产锚定 `releases/download/v([\\d.]+)/lazyjj-v\\1-x86_64-pc-windows-msvc\\.zip` → 解析回 `0.5.0` = 当前版本，不再触发失败（机制已实测同 KataGo；此条正则未单独跑，与 v0.5.0 URL 字面一致）。
- 倾向 (a)，理由：锚定只能防复发，不能带来新版本。

## 19. katago — 模板不变，换锚定 checkver

- 同 17。单 URL 模板保留；checkver 换 opencl 锚 → `1.18.1`。验证同 17（plain 200）。

## 20. katago-eigen — 模板不变，换锚定 checkver

- checkver 换 **eigen 锚**（实测→`1.18.1`；v1.18.2 无 eigen 资产）；4 URL 模板（eigen/eigenavx2 × plain/bs50）原样保留。
- **验证**: v1.18.1 四资产 HEAD **200×4**。

## 21. pdf-guru — **atom feed 被草稿 release 污染**，资产锚定自愈

- **旧模板**: `https://github.com/kevin2li/PDF-Guru/releases/download/v$version/pdf-guru-windows-amd64-$version.zip`；checkver: `tags.atom` + `releases/tag/v([\d.]+)`
- **现场（2026-10-01 实测）**:
  - `tags.atom` **和** `releases.atom` 都列出 `v1.1.3 / v1.1.2 / v1.0.13 / latest / v1.0.12` —— checkver 拿到 `1.1.3`（本次失败）。
  - 但 `api…/releases/tags/v1.1.3`、`/v1.1.2` 均 **404**；`/releases` 列表里根本没有它们 → 这三个是**未公开的草稿 release，泄漏进了两个 atom feed**（GitHub 已知行为）。tag `latest`（2023-09 创建、最近重建）零资产。
  - 最后一个真实发布 = `v1.0.12`（2023-07，4 资产，含 `pdf-guru-windows-amd64-1.0.12.zip`）。
- **结论**: 换 releases.atom 没用（同样被污染）。**资产锚定**是唯一稳定解：

```json
"checkver": {
    "url": "https://api.github.com/repos/kevin2li/PDF-Guru/releases?per_page=100",
    "regex": "releases/download/v([\\d.]+)/pdf-guru-windows-amd64-\\1\\.zip"
}
```

- 解析结果 `1.0.12` = 当前 manifest 版本 → checkver 不再报新版本，excavator 队列自愈。autoupdate.url 模板**不变**；上游若正式发布 1.1.3 且资产同名，锚定正则自动跟进。
- **验证**: v1.0.12 pinned 资产 HEAD **200**（38MB）；v1.1.3 下载 URL **404**（草稿不可下载）。
- **风险注记**: manifest 将停留在 1.0.12 直至上游真正发布 release；这是上游问题，非 bucket 可修。

## 22. keploy — 扩展名消失（裸二进制）+ 删 arm64

- **旧模板**: `…/download/v$version/keploy_windows_amd64.tar.gz`（arm64 同型）
- **真实资产**（v3.6.84，2026-10-01 发布；v3.6.80→3.6.84 连续 5 个 release 一致）: `keploy_windows_amd64`（**无扩展名**，octet-stream，71,286,272 B ≈ 68MB 裸 exe）、`keploy_linux_amd64.tar.gz`、`keploy_linux_arm64.tar.gz`、`keploy_darwin_arm64.tar.gz`。**没有 windows arm64**。
- **新模板**:

```json
"url": "https://github.com/keploy/keploy/releases/download/v$version/keploy_windows_amd64#/keploy.exe"
```

（`#/keploy.exe` 是 scoop 对无扩展名裸二进制的标准重命名惯用法，参考本桶 ffmpegfreeui 修法）
- **验证**: 无扩展名 URL HEAD **200**；旧 `.tar.gz` **404**；`keploy_windows_arm64` **404**。
- **连带改动**: **删除整个 `arm64` 架构块**（architecture + autoupdate）；`bin: "keploy.exe"` 不变；checkver `"github"` 不变（tag `v3.6.84` → `3.6.84`）。
- **版本**: 2.12.3 → `3.6.84`（大版本跳跃正常跟随）。

## 23. katago-tensorrt — 换 trt8 为 trt10.16.1 + 修既存 bin bug

- **checkver**: 换 **trt10.2.0 锚**（实测→`1.18.1`；v1.18.2 无任何 trt 资产）。
- **URL 集合**（6 个，v1.18.1）: `trt10.2.0-cuda12.5`、`trt10.9.0-cuda12.8`、**`trt10.16.1-cuda13.2`（新）** 各 × plain/bs50；**删 `trt8.6.1-cuda12.1`**（v1.18.1 不存在；官方 notes: "TensorRT versions older than 10 are not supported"）。
- **验证**: 6 个 URL HEAD **200×6**（trt10.16.1 亦 200）。
- **连带改动**:
  - `extract_to` / `bin`: 删 `katago-tensorrt8(-bs50)` 两条，加 `katago-tensorrt10.16.1(-bs50)` 两条（bin 名建议 `katago-tensorrt10161`）。
  - **修既存 bug（与本任务无关但同文件顺手）**: bin 第 4 条 `["katago-tensorrt10.2.0-bs50/katago.exe", "katago-tensorrt109-bs50"]` 路径错指 10.2.0-bs50，应为 `katago-tensorrt10.9.0-bs50/katago.exe`。
- **版本**: 1.16.5 → `1.18.1`。

## 24. pachi — win64 拆 avx/noavx，win32 已死

- **旧模板**: 64bit `pachi-$version-win64.zip`；32bit `pachi-$version-win.zip`；`extract_dir: "Pachi-$version"`
- **资产时间线**: 12.84 = 旧命名（win/win64）；**12.86 起改为 `win64-avx` / `win64-noavx`，win32 彻底消失**；12.88/12.90 延续（另有 linux 三件套）。
- **新模板（64bit）**（12.86 起固定为 avx/noavx 双轨命名）:

```
https://github.com/pasky/pachi/releases/download/pachi-$version/pachi-$version-win64-avx.zip
```

- **验证**: `pachi-12.90-win64-avx.zip` HEAD **200**（63MB）、`win64-noavx.zip` **200**（37MB）；旧 `win64.zip`/`win.zip` **404**。全量下载 avx 包解析：根目录 **`Pachi-12.90/`**（含 pachi.exe）→ `extract_dir: "Pachi-$version"` **不变**。
- **连带改动**: **删除 `32bit` 架构块**（architecture + autoupdate）；若想保底老 CPU 可在 notes 提 noavx 手动替换。checkver（`pachi-([\d.]+)`）不变——`katago_models` release 无 `pachi-` 前缀，不受干扰（本次 run checkver 成功拿到 12.90 佐证）。
- **版本**: 12.84 → `12.90`。

## 25. okegui — zip → 7z（目录结构未变）

- **旧模板**: `…/download/$version/OKEGui-v$version.zip`
- **失败 tag 9.1.5 真实资产**: **`OKEGui-v9.1.5.7z`**（唯一资产，180MB）
- **新模板**: `https://github.com/vcb-s/OKEGui/releases/download/$version/OKEGui-v$version.7z`
- **验证**: 7z HEAD **200**；旧 zip **404**。全量下载 7z 列表：根目录 **`OKEGui/`** → `extract_dir: "OKEGui"` **不变**；scoop 原生支持 7z 解压，shortcuts 不变。
- **版本**: 9.1.4 → `9.1.5`；checkver `"github"` 不变。

## 26. project-86 — **deprecate 候选**：上游迁 itch.io

- **旧模板**: `…/download/v$version/Project86-v$version.zip`
- **真实资产**: `v2.0.0-alpha.2`（2026-09-13，标记 stable）**零资产**（404 实测，上轮研究已确认）；`v2.0.0-alpha.1`（prerelease）有 `Project86-v2.0.0-alpha.1.zip`（HEAD **200**，2.03GB）+ linux zip；`v1.11.1-alpha`（当前 pinned）资产 200。
- **release notes 原文（v2.0.0-alpha.2）**: "**/!\\ DOWNLOAD HERE -> https://project-86.itch.io/project-86** … For user experience, we now publish the releases through itch.io. **GitHub is also no longer used** in preference to Unity VCS." —— GitHub 资产分发已官方终止，后续 release 预计均零资产。
- **建议**:
  - **首选 (a) deprecate 候选**: itch.io 无稳定直链，不可 autoupdate；GitHub 渠道已死。
  - 备选 (b) 若暂不 deprecate：资产锚定 checkver 冻结在最后一个有 zip 的 release → `2.0.0-alpha.1`：

```json
"checkver": {
    "url": "https://api.github.com/repos/Taliayaya/Project-86/releases?per_page=100",
    "regex": "releases/download/v([\\d.]+(?:-alpha(?:\\.\\d+)?)?)/Project86-v\\1\\.zip"
}
```

（需带 `-alpha` 后缀捕获组；正则未单独实测，机制已实测同 KataGo，且目标 URL 已 HEAD 200。此时版本 `1.11.1-alpha`→`2.0.0-alpha.1`，shortcuts/模板不变。）
- 注意 (b) 以后每次都会下载 2GB alpha 测试版（notes 原文: "A test session is not the release. Missions may be missing, stats will change, progression and rewards may be wiped"）——对 scoop 用户并不合适，进一步支持 (a)。

---

## 验证记录（全部 2026-10-01 实测）

- **HEAD 200**: inkeys×3（20260713a）；hatch 新名；pachi win64-avx/noavx；okegui 7z；keploy 新名；pdf-guru v1.0.12；lazyjj v0.5.0；project86 v1.11.1-alpha + v2.0.0-alpha.1；katago v1.18.1 × 18（opencl/eigen/eigenavx2/trt×3/cuda×3 全部 plain+bs50）；katago v1.18.2 × 12（6 CUDA 变体 plain+bs50 windows）
- **HEAD 404（复现失败）**: inkeys 无-a 名；hatch 旧名；pachi 旧 win64/win 名；okegui zip；keploy 旧 .tar.gz + windows_arm64；lazyjj v0.6.1；project86 v2.0.0-alpha.2；katago v1.18.2 opencl
- **API**: 9 repo `releases?per_page=5`；KataGo `tags/v1.18.2` + `/assets?per_page=100`（24=全量）；3 个 release body；PDF-Guru `tags/v1.1.3|v1.1.2`（404）；锚定正则 live 实测（opencl/eigen/trt×3/cuda12.8）；两个 atom feed 现场抓取
- **zip/7z 内部结构**: hatch（`hatch.exe` 单文件）、pachi 12.90 avx（`Pachi-12.90/`）、OKEGui 9.1.5（`OKEGui/`）
- **本桶先例**: `bucket/veyon.json`（api.github.com checkver）；`bucket/project-86.json`（github+regex 组合）
- 上轮研究复用: `.trellis/tasks/archive/2026-10/10-01-fix-excavator-checkver/research/b1-dash-fixes.md`（project-86 零资产线索，本轮已升级为 itch.io 迁移结论）

## Caveats / 未尽事项

1. **主 agent 决策点**: lazyjj（deprecate vs 锚定冻结 0.5.0）、project-86（deprecate vs 锚定 alpha.1）、katago-full（最小 16 URL vs 扩展至含 rocm/openvino/directml）、keploy arm64 与 pachi 32bit 的删除确认。
2. katago 家族 5 个 manifest 的锚定 checkver 每次 excavator run 消耗 5 个匿名 API 请求（+pdf-guru 1 个）；若未来 bucket 扩大需注意 60/h 限额（veyon 已占用 1）。
3. 未单独实测的锚定正则：lazyjj、project-86 两条（目标 URL 已分别 HEAD 200，机制同已实测的 KataGo）；实现后建议跑一次 `scoop checkver` 验证。
4. hatch 1.18.1 zip 仅含 `hatch.exe`，但 hash 需 excavator 重新生成（本篇不产出 hash）。
