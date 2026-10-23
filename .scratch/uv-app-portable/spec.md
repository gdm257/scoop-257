# uv app template 完全便携化

Status: ready-for-agent

## Problem Statement

基于 uv 的 app manifest 模板（`bucket/app-uv.json.template`）当前直接调用 PATH 里的 `uv`：Python 解释器装到 uv 的全局默认目录（`%APPDATA%\uv`），wheel cache 落在 `%LOCALAPPDATA%`，且 uv 默认偏好会静默使用系统已装的 Python。结果是 app 不便携——换机器、换 scoop 根目录、甚至 scoop update 后行为不一致，卸载在全局目录留残留。

## Solution

模板改为在安装期于 `$dir` 内生成 per-app wrapper（CLI 用 `.cmd`、GUI 用 `.vbs`），运行时以脚本自身位置（`%~dp0` / `WScript.ScriptFullName`）为基础，把 uv 管理的 Python、可执行入口、cache 全部定位到 app 自己的 `$dir` 内，并强制 `only-managed` 偏好（永不使用系统 Python）。Python、`.venv`、cache 随 `$dir` 被 Scoop 统一管理生命周期：更新即重建、卸载零残留。决策已沉淀于 ADR `docs/adr/0001-uv-app-fully-portable-in-dir.md`。

## User Stories

1. As a bucket 维护者, I want 模板生成的 app 把 uv 管理的 Python 装进 `$dir\py`, so that 卸载时解释器随 `$dir` 一起清除、不在全局目录留残留。
2. As a bucket 维护者, I want wheel cache 落在 `$dir\uv-cache`, so that 整个 app 自包含、拷走目录即完整迁移。
3. As a bucket 维护者, I want `UV_PYTHON_PREFERENCE=only-managed`, so that 任何机器上行为一致，绝不静默落到系统 Python。
4. As a bucket 维护者, I want env 注入由 `$dir` 内生成的 wrapper 在运行时完成, so that 不污染用户全局环境变量、不影响机器上其他 uv 使用。
5. As a bucket 维护者, I want wrapper 里的路径基于脚本自身位置而非写死的绝对路径, so that 目录整体搬移（换盘、换机器、版本号变化）后无需修改仍能工作。
6. As a 使用者, I want 安装完成即可运行 app, so that 不需要首次启动时等待现场下载 Python 和依赖。
7. As a 使用者, I want GUI shortcut 启动时不闪控制台窗口, so that 体验与原生 GUI app 一致。
8. As a 使用者, I want CLI shim 透传退出码和参数, so that 脚本化调用行为正常。
9. As a 使用者, I want app 与全局 uv 安装互相隔离, so that 全局升级 uv 或删掉全局 Python 不影响已装 app。

## Implementation Decisions

- 目录布局：`UV_PYTHON_INSTALL_DIR=$dir\py`、`UV_PYTHON_BIN_DIR=$dir\py\bin`、`UV_CACHE_DIR=$dir\uv-cache`；`.venv` 留在项目根（uv 默认）。
- 注入机制：模板 `installer` 在 `$dir` 生成 `uv-env.cmd`（CLI）与 `uv-env.vbs`（GUI）两个 wrapper；`.cmd` 设四个 env 后 `call` 同目录现有的 `command-wrapper.cmd` 并透传参数；`.vbs` 在进程环境设四个 env 后复用现有 `command-wrapper.vbs` 的候选解析 + 隐藏窗口运行逻辑。不使用 manifest `env_set`，不修改 `scripts/command-wrapper/` 共享脚本。
- `bin` 条目指向生成的 `uv-env.cmd`；`shortcuts` 指向生成的 `uv-env.vbs`。
- 安装期：installer 脚本先以 `Join-Path $dir ...` 设置同名 `$env:UV_*` 与偏好，再执行 `uv init/add/sync`，保证装完首启即用。
- 更新语义：`scoop update` 清空 `$dir` 即重下 Python、重建 venv/cache——接受的代价（见 ADR 0001）；个别 app 可在自身 manifest 改用 persist，属例外不回改模板。
- wrapper 内容不含绝对路径；路径全部由脚本自身位置运行时推导。

## Testing Decisions

- 只测外部行为：在临时目录布置生成的 wrapper、一个 stub 候选命令（dump 收到的 `UV_*` 环境变量与转发参数）及假目录骨架，直接调用 wrapper，断言变量按脚本所在目录正确展开、参数与退出码透传、找不到候选时报错。不测 wrapper 内部实现，不测共享 `command-wrapper` 自身。
- 覆盖对象：`uv-env.cmd` 与 `uv-env.vbs` 两个生成物（模板 installer 的生成逻辑通过生成结果间接覆盖）。
- Seam 唯一：wrapper 脚本以 stub 命令为被包装对象。无既有单测先例，属本仓库首个脚本级单测。
- 零外部依赖，Windows 上以 `cmd` / `cscript` 原生运行。

## Out of Scope

- 修改共享 `scripts/command-wrapper/` 脚本。
- 将 Python/venv/cache 放入 `$persist_dir` 的变体（ADR 已否决）。
- 非 Windows 平台。
- 既有具体 app manifest 的迁移改造（模板更新后另行处理）。
- 持久化用户数据（app 自身配置仍走各 manifest 的 `persist`）。

## Further Notes

- ADR：`docs/adr/0001-uv-app-fully-portable-in-dir.md` 记录了"全放版本化 `$dir`、更新即重建"的权衡与被否选项。
- `.vbs` 实现取最小 diff：优先复制现有 `command-wrapper.vbs` 加环境设置段，而非重写精简版。
- 模板是 `.template`，无 `checkver/autoupdate`；本变更不引入版本字段变化。
