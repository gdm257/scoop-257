# Fix excavator checkver failures

来源：excavator workflow run #36732909371 / #36753459991 日志分析（2026-10-01）。

## 根因（research 已验证）

1. **API/HTML 模式失配（A2，20 个）**：excavator 设了 `GITHUB_TOKEN`，scoop 的 `checkver: github` 简写会用 API 模式——**regex 只匹配裸 `tag_name`**。现有 regex 全是 HTML 锚（`releases/tag/...`、`<title>`、资产名），永远失配。修法：去掉 HTML 上下文，regex 直接匹配 tag 主体。
2. **默认 regex 吞破折号（B1，11 个）**：无自定义 regex 时默认 `(?:v|V)?([\d.-]+)`，`[\d.-]` 吃掉 `-` 后在字母处停 → `1.4.0-`、`2.0-`、`9-`。修法：加自定义 regex 捕获完整 prerelease 后缀。
3. **版本语义错（A3 + onscripter-ru）**：OsuBeatmapDownloader/onscripter-ru 的真实版本只在 release **name**（tag 是 `26`/`untagged-<hash>`），需显式 URL + name regex。shutter-image-browser 不是 bug，是真·新版（本轮不动）。

## 修改清单

### 批量 commit 1：checkver regex 修复（35 个）

| 组 | Apps | 修法（详见 research/*.md，regex 已对真实 tag 验证） |
|---|---|---|
| A2 tag_name regex（20） | dango-translator, ffmpegfreeui, datax, hunt-and-peck, evil-helix, hatch, kotlin-lsp, fleetctl, foundation-sunshine, JHenTai, iii, nsmusics, real-video-enhancer, peri, rivet, translumo, pachi, veyon, wakatime, q5go | 去 HTML 锚，匹配裸 tag_name；JHenTai/wakatime 保留 replace/命名组（autoupdate 依赖） |
| B1 后缀捕获（7） | froggit, airi, allusion, mykeymap, gclone, project-86, revezone | github + 捕获完整后缀的 regex |
| B1 稳定版锁定（2） | fx, zoraxy | `releases.atom` + `</title>` 锚定的 stable-only regex（修后 checkver 即绿，不 bump） |
| B1 主版本锁定（2） | wsl-centos-7, wsl-centos-8 | `releases.atom` + `CentOS (7…)`/`(8…)` major-pin regex |
| A3 name-based（2） | OsuBeatmapDownloader, onscripter-ru | 显式 releases/latest URL + release name regex |
| 自家项目（1） | octopus-257 | regex 改 `v([\w.-]+)`，下轮自动更到 0.13.9-post.1 |

注意：foundation-sunshine regex 含原始 CJK 字符，过 formatjson 时 manifest 必须保持 UTF-8。

### 批量 commit 2：死上游 deprecated（2 个）

- **chrome-plus** → `deprecated/`：上游账号+仓库+安装资产全灭，无 regex 可修
- **WinDeckHelper** → `deprecated/`：releases/tags 全删、安装 URL 404，上游改无版本 main-branch 分发

### 批量 commit 3：softalk 换源（1 个）

checkver/url/autoupdate 三处 host 从 `blitz.starfree.jp` 换到 `softalk.stars.ne.jp`；commit 前本地 smoke test 新站可达性。

### 批量 commit 4：git-ssh-sign 去 checkver（1 个）

删除 checkver/autoupdate 字段（内联脚本无上游；excavator 跳过无 checkver 的 manifest，已在 checkver.ps1 验证）。

## 明确不做

- B2 资产 URL 404（29 个）：下轮任务。project-86 / dango-translator / kotlin-lsp regex 修好后会暴露为 B2 噪音，属预期
- WSABuildsWindows10/11：保留现状
- shutter-image-browser：真·新版但无 autoupdate，不在本轮 bump

## 验证（已确认）

1. 每个改动 manifest：本地 `scoop checkver <name>` 通过（与 bucket 中 version 一致或正确报新版）
2. 会触发新版本的（B1 后缀捕获组、octopus-257）：HEAD 请求验证按新版本拼出的 autoupdate URL 真实存在（200/302）
3. softalk：换源后 URL 可达
4. 推送后观察下一轮 excavator 日志作为最终回归

## 提交

4 个批量 commit（上表），Angular 风格，如 `fix(checkver): ...` / `chore: deprecate ...`。
