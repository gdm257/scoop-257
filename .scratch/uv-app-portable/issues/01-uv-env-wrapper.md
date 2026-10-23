# 01: uv app template 完全便携化（uv-env wrapper，CLI + GUI）

**What to build:** 基于 `bucket/app-uv.json.template` 安装的 app 完全便携：模板 installer 在 `$dir` 生成 `uv-env.cmd` 与 `uv-env.vbs` 两个 per-app wrapper，运行时以脚本自身位置定位 uv 管理的 Python（`$dir\py`）、可执行入口（`$dir\py\bin`）与 wheel cache（`$dir\uv-cache`），并强制 `only-managed` 偏好；`bin` / `shortcuts` 分别指向生成的 wrapper；installer 先设同名 `$env:UV_*` 再执行 `uv init/add/sync`，装完首启即用。不使用 manifest `env_set`，不修改共享 `scripts/command-wrapper/` 脚本。决策依据见 spec（`.scratch/uv-app-portable/spec.md`）与 ADR `docs/adr/0001-uv-app-fully-portable-in-dir.md`。

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] installer 在 `$dir` 生成 `uv-env.cmd`：设 `UV_PYTHON_INSTALL_DIR` / `UV_PYTHON_BIN_DIR` / `UV_CACHE_DIR` / `UV_PYTHON_PREFERENCE` 四个变量（路径基于 `%~dp0`，不含写死的绝对路径），然后 `call` 同目录 `command-wrapper.cmd` 并透传全部参数
- [x] installer 在 `$dir` 生成 `uv-env.vbs`：复用现有 `command-wrapper.vbs` 的候选解析、隐藏窗口运行、退出码透传逻辑，仅增加进程环境变量设置段
- [x] `bin` 条目指向 `uv-env.cmd`，`shortcuts` 指向 `uv-env.vbs`
- [x] installer 先以 `Join-Path $dir ...` 设置 `$env:UV_*` 与 `only-managed`，再执行 `uv init/add/sync`
- [x] 单测（仓库首个脚本级单测，零外部依赖，Windows 原生 `cmd`/`cscript` 运行）：临时目录布置生成的 wrapper + stub 候选命令（dump 收到的 `UV_*` 与转发参数）+ 假目录骨架，断言 env 按脚本所在目录正确展开、参数与退出码透传、无候选时报错；`.cmd` 与 `.vbs` 均覆盖
- [x] 不修改 `scripts/command-wrapper/` 共享脚本，不引入 manifest `env_set`
