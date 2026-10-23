# uv app template: fully portable, everything inside versioned `$dir`

Scoop bucket 中基于 uv 的 app 模板（`bucket/app-uv.json.template`）的便携化决策：uv 管理的 Python 解释器（`UV_PYTHON_INSTALL_DIR` / `UV_PYTHON_BIN_DIR`）、wheel cache（`UV_CACHE_DIR`）与 `.venv` 全部放在版本化的 `$dir` 内（`$dir\py\`、`$dir\uv-cache`），`UV_PYTHON_PREFERENCE=only-managed` 永不使用系统 Python；env 变量由模板在 `$dir` 生成的 per-app wrapper 在运行时注入，不使用 manifest `env_set`（避免污染用户全局环境、影响机器上其他 uv 使用）。

## Considered Options

- Python 放 `$persist_dir`：被否——venv 内记录绝对路径，`$dir` 版本号一变 venv 照样失效，仍需重 sync；省的只有解释器下载，且卸载后 persist 残留。

## Consequences

- 每次 `scoop update` 重新下载 Python 并重建 venv/cache；installer 必须在设好同名 `$env:UV_*` 后执行 `uv sync`，保证装完首启即用。
- 个别在意更新耗时/流量的 app 可自行改用 persist，属 manifest 级例外，不回改模板。
