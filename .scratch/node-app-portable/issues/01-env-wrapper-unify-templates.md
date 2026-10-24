# 01: 通用 env-wrapper 落地，uv/pnpm/bun 三模板统一便携化

**What to build:** 安装后（uv/pnpm/bun 三类 app template 生成的）app 完全便携：installer 在 `$dir` 复制共享 wrapper 并生成 `app-env.cmd`（`set "KEY=%~dp0..."` 形式声明环境变量），`bin`/`shortcuts` 指向通用 `env-wrapper.cmd`/`env-wrapper.vbs`；wrapper 运行时读取 `app-env.cmd` 注入环境（路径由脚本自身位置推导，无写死绝对路径）后复用 command-wrapper 逻辑执行命令并透传参数/退出码。pnpm 设 `pnpm_config_store_dir` 指向 `$dir\pnpm-store`，bun 设 `BUN_INSTALL_CACHE_DIR` 指向 `$dir\bun-cache`（运行时 node/bun 留外部，仅 PATH 裸命令依赖）；uv 四变量沿用 ADR 0001 布局。uv 模板与既有 uv manifest（bethini-pie）一并迁移，`scripts/uv-env/` 删除，无双轨。installer 先设同名 `$env:` 再执行安装命令（uv `--directory`、pnpm `--dir`、bun `Set-Location` 后 `bun install`）。不修改共享 `scripts/command-wrapper/`，不使用 manifest `env_set`。决策依据见 spec（`.scratch/node-app-portable/spec.md`）、ADR 0002 与 GLOSSARY.md。

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] `scripts/env-wrapper/env-wrapper.cmd`：`call` 同目录生成的 `app-env.cmd` 后 `call` 同目录 `command-wrapper.cmd`，透传全部参数与退出码；`app-env.cmd` 缺失时明确报错
- [x] `scripts/env-wrapper/env-wrapper.vbs`：复用 command-wrapper.vbs 的候选解析、隐藏窗口运行、退出码透传逻辑，新增解析 `app-env.cmd` 的 `set "KEY=VALUE"` 行、把 `%~dp0` 字面量替换为脚本自身目录并注入进程环境的段落；`app-env.cmd` 缺失或解析失败时明确报错
- [x] 三个模板（uv/pnpm/bun）installer：Copy-Item 共享 wrapper → 生成 `app-env.cmd`（`%~dp0` 相对路径）→ 设同名 `$env:` → 执行安装命令；`bin` 指向 `env-wrapper.cmd`，`shortcuts` 指向 `env-wrapper.vbs`
- [x] bethini-pie manifest 迁移到通用 wrapper + `app-env.cmd`
- [x] 删除 `scripts/uv-env/`，仓库内无 uv-env 残留引用
- [x] `scripts/tests/test-uv-env.cmd` 改造为 `test-env-wrapper.cmd`（stub 复用），覆盖：env/args 按 wrapper 所在目录展开、`%~dp0` 正确替换、参数与退出码透传、目录搬移后仍工作、`app-env.cmd` 缺失报错、无候选报错，`.cmd`/`.vbs` 双覆盖；零外部依赖
- [x] 不修改 `scripts/command-wrapper/`，不引入 manifest `env_set`
