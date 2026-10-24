---
name: scoop
description: >
  Scoop bucket manifest conventions for this repo. Use when writing or editing
  a manifest (json in bucket root), fixing checkver/autoupdate regex failures,
  triaging excavator logs, or bumping versions/hashes.
---

# Scoop Bucket Manifest Conventions

本 bucket（gdm257）的 manifest 编写、checkver/autoupdate 与 excavator 维护约定。
通用字段定义查 Scoop wiki；本文只缓存环境查不到的实证结论。

## Commit Messages

| Area                   | Style                      | Example                              |
| ---------------------- | -------------------------- | ------------------------------------ |
| Manifest / app files   | `<appname>: <description>` | `moonlight: Add version 6.2.79`      |
| Trellis / CI / tooling | `ci(<scope>): <message>`   | `ci(sdd): upgrade opencode package`  |
| Spec docs              | `docs(spec): <message>`    | `docs(spec): add bucket conventions` |

## 常用变量与 helper

- `$bucket` 是 bucket **名字字符串**，拼路径用 `Join-Path $bucketsdir $bucket`（或 `Find-BucketDirectory`）
- `appdir <name> $global` 解析 app 目录
- 复用脚本从 `scripts/` 拷进 `$dir`：
  `Copy-Item (Join-Path $bucketsdir $bucket 'scripts\<name>') (Join-Path $dir 'shim') -Recurse -Force`

## checkver 两种匹配模式（API / HTML）

`checkver.github` 的 regex 匹配对象取决于环境有无 `GITHUB_TOKEN`（excavator 有，本地没有）：

| 模式 | 触发条件 | regex 匹配对象 | 可用锚 |
| ---- | -------- | -------------- | ------ |
| **API 模式** | 有 `GITHUB_TOKEN` | `/releases/latest` 的裸 `tag_name` | 只能匹配 tag 本体 |
| HTML 模式 | 无 token | releases/latest 页面 HTML | `releases/tag/…`、`<title>` 等 |

本 bucket 主运行环境是 excavator（API 模式）：

- regex **不得**带 `releases/tag/`、`<title>` 等 HTML 锚——API 模式下永远失配，日志表现为 `couldn't match 'releases/tag/…'`（本地 checkver 却通过）
- 版本只在 release **name** 的项目（tag 是 `26`/`untagged-<hash>`）：显式 `checkver.url` 指向 releases/latest 页面 + 匹配标题
- 锁定稳定版/主版本（跳 prerelease）：`releases.atom` + `</title>` 锚（atom 只含最新 ~10 条）
- 需 tag 上下文锚又想兼容本地 HTML 验证：双模式锚 `(?:/releases/tag/|^)(…)`（先例：ffmpegfreeui、inkeys）

## 默认 regex 的截断缺陷

`"checkver": "github"` 不带 `regex` 时，默认 `(?:v|V)?([\d.-]+)` 会截断，凡 tag 带下列形态必须显式写 regex：

| tag 形态 | 默认产出 | 应捕获 | 先例 |
| -------- | -------- | ------ | ---- |
| prerelease `v1.4.0-rc.1` | 畸形 `1.4.0-` | `1.4.0-rc.1` | — |
| 字母后缀 `v0.7.7beta` | 截断 `0.7.7` | 完整含后缀 | OnscripterYuri、inkeys |
| 下划线后缀 `v0.8.1_upd1` | 截断 `0.8.1` | `1.0.8.1_upd1` | dismtools |
| monorepo tag `v1.1.9_snow-shot` | 截断（拼 tag 404） | 版本 + tag 段后缀以字面量进模板 | snowshot |

checkver regex 命名组（`(?<base>…)`）与 autoupdate 的 `$matchBase` 模板是上下游契约；改 regex 前先查 autoupdate 引用了哪些组。

## Pattern: 资产锚定 checkver

部分发布（上游只重编部分资产）或 tag 与资产不同步时，`releases/latest` 的 tag 版本可能无目标资产 → autoupdate 404；atom feed 还会被 draft release 污染（幽灵版本，先例 pdf-guru）。

解法：checkver 锚定资产 URL 本身——`checkver.url` 指向 releases API 列表，regex 反向引用匹配完整资产名：

```json
"checkver": {
    "url": "https://api.github.com/repos/lightvector/KataGo/releases?per_page=100",
    "regex": "releases/download/v([\\d.]+)/katago-v\\1-opencl-windows-x64\\.zip"
}
```

- 语义：按 release 顺序找第一条含匹配资产的记录，自动跳过无此资产的更新版
- 反向引用 `\1` 保证 tag 版本与资产内嵌版本一致；正则错一个字符即失配（响亮失败优于静默 404）
- 代价：每个锚定 manifest 为 excavator run 增加 1 次匿名 API 调用
- 手动 bump pinned 状态时 hash 必须填真值（GitHub API 资产 digest 字段即 sha256）——version == checkver 结果时 autoupdate 不触发，占位 hash 永久滞留（先例：katago-tensorrt）

## excavator 失败 triage（月度）

excavator job 整体永远 success——失败只刷日志。定期拉日志分类：

| 日志特征 | 分类 | 处置 |
| -------- | ---- | ---- |
| `couldn't match '<regex>' in …` | regex 失配 | 对照真实 `tag_name` 改 regex（API 模式语义） |
| 版本尾随 `-` | 默认 regex 吞 prerelease | 补显式 regex |
| `autoupdate available` 后接 `URL … is not valid` | 资产 URL 漂移 | 对照实际资产名改 autoupdate.url 模板 |
| checkver URL 404/超时 | 上游死亡 | 查证后移 `deprecated/`；仅搬家则换源 |
| `X: v (scoop version is y)` 无 `autoupdate available` | 无 autoupdate 或版本语义错 | 补配置或修 regex |

验证顺序：regex 以 API 模式为准 → 会触发新版本的用 HEAD 验证拼出的 URL → 回归看下一轮 excavator 日志。

## 批量修复的分派核对

批量 triage（数十个 manifest）两处曾出错：

- 分派清单必须由 input 失败清单逐行映射生成，不得手抄方案表（曾漏 snowshot）；check 阶段对账 input 行数 == 方案数 == 实际改动数
- research 结论含 checkver regex 时必须按 API 模式语义验证并注明验证模式（HTML 模式通过的正则 excavator 下可能永远失配，先例 inkeys）

## Gotchas

- `shortcuts` / COM `CreateShortcut` 走 ANSI API，CJK/emoji 名字变 `??`（Scoop#2585，无上游修复）
- `--global` 只改安装目录与作用域；脚本仍在当前 PowerShell 进程内以该用户执行，Scoop 不切 SYSTEM 也不单独提权
- `persist`：目录 junction、文件 hardlink；`scoop reset` 冲突时 `$dir` 被 `$persist_dir` 整体覆盖，无合并
- bucket 状态损坏：`scoop bucket rm <name> && scoop bucket add <name>` 最快修复
- URL fragment `#/dl.7z` / `#/name.exe` 强制 Scoop 按指定格式处理下载

## Pattern: which-shim

PATH 回退命令 shim，候选以分号分隔作第一个参数：

```json
{
    "installer": {
        "script": "Copy-Item (Join-Path $bucketsdir $bucket 'scripts\\which-shim') (Join-Path $dir 'shim') -Recurse -Force"
    },
    "bin": [["shim\\which.cmd", "python3", "python3.exe;python.exe"]]
}
```

流程：`which.cmd` → `which.ps1` 按 `;` 拆 `$args[0]` → 逐个 `Get-Command` → 第一个命中者带剩余参数执行。实现在 `scripts/which-shim/`。
