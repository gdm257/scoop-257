# pnpm/bun app template 便携化 + 通用 env-wrapper

Status: ready-for-agent

## Problem Statement

pnpm/bun 两个 app template（`bucket/app-pnpm.json.template`、`bucket/app-bun.json.template`）目前直接使用 PATH 里的 pnpm/bun：pnpm 的全局 store 落在 `~/AppData/Local/pnpm/store`，bun 的包 cache 落在 `~/.bun/install/cache`，均与 Scoop 的 `$dir` 生命周期脱钩——卸载残留、目录整体迁移后丢 cache、且 uv 模板已便携化而这两个模板仍是旧 command-wrapper 直连形态，模板间不一致。同时 uv 模板的 per-manager wrapper（uv-env）若照搬会给 pnpm/bun 各复制一份 113 行的 `.vbs` 大副本。

## Solution

三个 app template（uv/pnpm/bun）统一改用新的通用 wrapper `scripts/env-wrapper/env-wrapper.cmd|.vbs`：installer 在 `$dir` 生成 `app-env.cmd`（`set "KEY=%~dp0..."` 行形式声明该 app 的环境变量），wrapper 运行时读取它注入环境后复用 command-wrapper 的候选解析与运行逻辑；pnpm 设 `pnpm_config_store_dir` 指向 `$dir\pnpm-store`，bun 设 `BUN_INSTALL_CACHE_DIR` 指向 `$dir\bun-cache`，运行时（node/bun）留外部（仅 PATH 裸命令依赖，由 scoop `suggest` 提示安装）。uv 模板与既有 uv app manifest 一并迁移到通用 wrapper，`scripts/uv-env/` 退役，无过渡双轨。决策依据：ADR `docs/adr/0002-node-app-templates-portable-store-cache.md`（承接 0001），术语见 `GLOSSARY.md`。

## User Stories

1. As a bucket 维护者, I want pnpm store 落在 `$dir\pnpm-store`, so that 卸载时 store 随 `$dir` 清除、不留全局残留。
2. As a bucket 维护者, I want bun cache 落在 `$dir\bun-cache`, so that 整个 app 自包含、拷走目录即完整迁移。
3. As a bucket 维护者, I want 三个模板共用一个通用 env-wrapper 而非各持一份 `.vbs` 副本, so that wrapper 逻辑只维护一处。
4. As a bucket 维护者, I want 每个 app 的环境变量以 installer 生成的 `app-env.cmd` 数据文件声明, so that 新增模板不需要写新 wrapper。
5. As a bucket 维护者, I want wrapper 与 `app-env.cmd` 内不含写死的绝对路径（路径由脚本自身位置 `%~dp0` 推导）, so that 目录搬移（换盘、换版本号）后无需修改仍能工作。
6. As a bucket 维护者, I want pnpm 前缀用 `pnpm_config_` 而非 `npm_config_`, so that pnpm v11 移除 `npm_config_` 支持后模板不失效。
7. As a bucket 维护者, I want uv 模板与既有 uv manifest（bethini-pie）一并迁移到通用 wrapper, so that 仓库无双轨 wrapper。
8. As a 使用者, I want 安装完成即可运行 app, so that 不需首启时现场下载依赖（installer 期已设同名 `$env:` 并完成 install）。
9. As a 使用者, I want GUI shortcut 启动不闪控制台窗口, so that 体验与原生 GUI 一致。
10. As a 使用者, I want CLI shim 透传退出码和参数, so that 脚本化调用行为正常。
11. As a 使用者, I want node/bun 未安装时得到明确的找不到候选报错, so that 排障直观。
12. As a 使用者, I want app 与机器上其他 pnpm/bun 使用互相隔离, so that 全局配置/升级不影响已装 app。
13. As a 使用者, I want `app-env.cmd` 缺失或无法解析时 wrapper 明确报错, so that 环境注入静默失效不会引发更隐蔽的下游故障。

## Implementation Decisions

- 运行时留外部：模板对 node/bun 的依赖仅限 PATH 裸命令（`node` / `bun`），由 `suggest` 提示安装；不使用 `pnpm env use` 托管 Node（ADR 0002 已否决）。
- env 变量：pnpm `pnpm_config_store_dir` → `$dir\pnpm-store`；bun `BUN_INSTALL_CACHE_DIR` → `$dir\bun-cache`；uv 四变量（`UV_PYTHON_INSTALL_DIR=$dir\py`、`UV_PYTHON_BIN_DIR=$dir\py\bin`、`UV_CACHE_DIR=$dir\uv-cache`、`UV_PYTHON_PREFERENCE=only-managed`）沿用 ADR 0001 布局不变。
- 通用 wrapper：`env-wrapper.cmd` `call` 同目录生成的 `app-env.cmd` 后 `call` 同目录 `command-wrapper.cmd` 透传参数与退出码；`env-wrapper.vbs` 为 command-wrapper.vbs 逻辑副本，运行时解析 `app-env.cmd` 的 `set "KEY=VALUE"` 行并把 `%~dp0` 字面量替换为脚本自身目录后注入进程环境。不修改共享 `scripts/command-wrapper/`。
- 模板 `bin` 指向 `env-wrapper.cmd`，`shortcuts` 指向 `env-wrapper.vbs`；installer 先 Copy-Item 共享 wrapper 到 `$dir`，再生成 `app-env.cmd`（`%~dp0` 相对路径），再设同名 `$env:` 后执行安装命令。
- installer 安装命令：uv 沿用 `uv --directory "$dir" init/add/sync`；pnpm `pnpm --dir "$dir" install`；bun `Set-Location $dir` 后 `bun install`（bun install 无 `--cwd` 参数）。
- 迁移：uv 模板、bethini-pie manifest 改指向通用 wrapper 并生成 `app-env.cmd`；`scripts/uv-env/` 删除；`scripts/tests/test-uv-env.cmd` 改造为 `test-env-wrapper.cmd`（stub 复用）。

## Testing Decisions

- 只测外部行为，沿用仓库唯一既有 seam：生成的 wrapper 调用 stub 候选命令（dump 收到的环境变量与转发参数/退出码），不测 wrapper 内部实现、不测共享 command-wrapper、不测模板 JSON 本身。
- 覆盖对象：`env-wrapper.cmd` 与 `env-wrapper.vbs`，输入为 stub + 生成的 `app-env.cmd` + 假目录骨架。
- 用例在既有 8 项（env/args 相对脚本目录展开、参数与退出码透传、目录搬移后仍工作、无候选报错、`.cmd`/`.vbs` 双覆盖）基础上新增：`app-env.cmd` 中 `%~dp0` 正确替换为 wrapper 实际所在目录；`app-env.cmd` 缺失时报明确错误。
- 零外部依赖，Windows 原生 `cmd` / `cscript` 运行；先例为 `scripts/tests/test-uv-env.cmd`。

## Out of Scope

- 修改共享 `scripts/command-wrapper/` 脚本。
- pnpm/bun 已有 manifest 的迁移（本 bucket 当前无此类 manifest）。
- 用 `pnpm env use` 把 Node 托管进 `$dir`（ADR 0002 已否决）。
- 非 Windows 平台。
- persist 变体（承接 ADR 0001 结论）。

## Further Notes

- ADR 0002 记录了"运行时留外部 + store/cache 入 `$dir` + 通用 env-wrapper"的权衡与被否选项；机制上取代 ADR 0001 的 per-manager wrapper 部分，目录布局决策仍以 0001 为准。
- `.scratch/uv-app-portable/spec.md` 为上一轮过程工件，不改。
- 模板为 `.template`，无 `checkver/autoupdate`，不引入版本字段变化。
