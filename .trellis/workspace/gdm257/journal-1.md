# Journal - gdm257 (Part 1)

> AI development session journal
> Started: 2026-05-11

---



## Session 1: python3-shim manifest

**Date**: 2026-05-11
**Task**: python3-shim manifest

### Summary

Created python3-shim Scoop manifest with generic which-shim script (which.ps1/which.cmd) for PATH-based command fallback. Added bucket spec with manifest conventions including Scoop variables, bin triple format, and commit message style.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `a510e67` | (see git log) |
| `5f014b1` | (see git log) |
| `98290d0` | (see git log) |
| `6751daf9` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: 优化 bucket checkver 自动更新

**Date**: 2026-08-29
**Task**: 优化 bucket checkver 自动更新
**Branch**: `master`

### Summary

修复 28 个 manifest 的 checkver 与 autoupdate URL 模板，静态验证版本变量渲染和 JSON 语法；未做网络实测。

### Main Changes

- Detailed change bullets were not supplied; see the summary above.

### Git Commits

| Hash | Message |
|------|---------|
| `b626f9f` | (see git log) |

### Testing

- Validation was not recorded for this session.

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: command-wrapper: allow leading --workdir

**Date**: 2026-09-12
**Task**: command-wrapper: allow leading --workdir
**Branch**: `master`

### Summary

command-wrapper 三入口(ps1/cmd/vbs)支持前导 --workdir <path>，尾部与无 workdir 形式不变，last-wins，错误路径 rc=1；顺带修复 .cmd 括号块内 exit /b 丢退出码的既有 bug；manifest 1.1.0

### Git Commits

| Hash | Message |
|------|---------|
| `adfb7d5` | (see git log) |

### Status

[OK] **Completed**


## Session 4: winstctl: IaC manage Windows scheduled tasks

**Date**: 2026-09-12
**Task**: winstctl: IaC manage Windows scheduled tasks
**Branch**: `master`

### Summary

New scripts/winstctl (task + yq + schtasks XML): apply/destroy/run/import etc., bucket/winstctl.json manifest, empty-Command guard; added scripts spec layer to persist schtasks and mvdan/sh gotchas; full link smoke tested (repo + scoop install)

### Git Commits

| Hash | Message |
|------|---------|
| `8cc662a` | (see git log) |
| `3a3bc0e` | (see git log) |

### Status

[OK] **Completed**

## Session 5: Fix excavator checkver failures

**Date**: 2026-10-01
**Task**: 10-01-fix-excavator-checkver
**Branch**: `master`

### Summary

分析 excavator 日志定位 65 个失败，grilling 确认范围后修复：34 个 checkver regex（根因：GITHUB_TOKEN 下 API 模式只匹配裸 tag_name，HTML 锚全失配；默认 regex 吞 prerelease 破折号）、chrome-plus/WinDeckHelper 移 deprecated、softalk 换源并 bump 020108、git-ssh-sign 去 checkver。checkver API/HTML 模式语义沉淀入 bucket spec 与 CONTEXT.md。B2（29 个资产 URL 404）留下轮。

### Git Commits

| Hash | Message |
|------|---------|
| `5275a8a` | fix(checkver): repair 34 manifests for excavator API-mode tag matching |
| `b32794a` | chore: deprecate chrome-plus and WinDeckHelper (dead upstream) |
| `ceac242` | fix(softalk): move to softalk.stars.ne.jp and update to 020108 |
| `ed27cd3` | fix(git-ssh-sign): remove stale checkver and autoupdate |
| `2e684c7` | docs(spec): document checkver API/HTML mode semantics and gotchas |

### Status

[OK] **Completed**


## Session 5: Fix excavator asset-404 autoupdate failures (35 manifests)

**Date**: 2026-10-02
**Task**: Fix excavator asset-404 autoupdate failures (35 manifests)
**Branch**: `master`

### Summary

Round 2 of excavator triage: 37 manifests where checkver succeeded but autoupdate asset URLs 404ed. 35 fixed: 23 template repairs with collateral edits (extract_dir/innosetup/shortcuts/arch-block removal, kotlin-lsp new JetBrains CDN, snowshot _snow-shot tag suffix), 3 pure checkver suffix-capture regexes, KataGo family switched to asset-anchored API checkver (partial-release upstream, veyon precedent) + pdf-guru atom-draft self-heal, project-86/sudocode deprecated, aionui frozen. lazyjj/whoami left untouched per user decision. Spec gained asset-anchor pattern, suffix-truncation table, atom-draft gotcha. Verified via 50+ live HEAD checks (all 200) and byte-level hash comparison for pinned KataGo trt assets.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `6961a35` | (see git log) |
| `30869fe` | (see git log) |
| `7d83369` | (see git log) |
| `d98dfac` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
