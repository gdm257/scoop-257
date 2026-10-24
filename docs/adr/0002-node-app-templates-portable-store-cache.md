# node 系 app 模板便携化：store/cache 入 `$dir`，运行时留外部，通用 env-wrapper

Scoop bucket 中 pnpm/bun app 模板（`bucket/app-pnpm.json.template`、`bucket/app-bun.json.template`）的便携化决策：与 ADR 0001 的 uv 模板不同，node/bun 运行时不收进 `$dir`——模板对运行时的依赖仅限 PATH 裸命令（`node` / `bun`，由 scoop `suggest` 提示安装），只把包管理器的全局态收进版本化 `$dir`：pnpm 设 `pnpm_config_store_dir=$dir\pnpm-store`（选 `pnpm_config_` 前缀而非 `npm_config_`，后者 pnpm v11 将移除），bun 设 `BUN_INSTALL_CACHE_DIR=$dir\bun-cache`；`node_modules` 留在项目根。三个模板（uv/pnpm/bun）共用一个通用 wrapper `scripts/env-wrapper/env-wrapper.cmd|.vbs`：运行时读取 `$dir` 内 installer 生成的 `app-env.cmd`（`set "KEY=%~dp0..."` 行），路径全部由脚本自身位置推导，取代 per-manager 的 uv-env 副本；uv 模板与既有 manifest 一并迁移，无过渡双轨。

## Considered Options

- pnpm 用 `pnpm env use` 把 Node 版本管进 `$dir`：被否——运行命令需改走 pnpm 托管 node、需额外设 `PNPM_HOME`，复杂度不值得；node 本就是 scoop 包，生命周期已受 scoop 管。
- per-manager wrapper（pnpm-env/bun-env 各一份 113 行 `.vbs` 副本）：被否——三份大副本难维护。

## Consequences

- bun 模板 installer 用 `Set-Location $dir` 再 `bun install`（bun install 无 `--cwd` 参数）；pnpm 用 `pnpm --dir "$dir" install`。
- 运行时缺失（node/bun 未装）表现为 command-wrapper 的"找不到候选"报错，与现状一致。
