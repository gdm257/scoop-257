# Scoop Bucket gdm257

个人 Scoop bucket，维护 app manifests 与配套安装脚本、模板。

## Language

**app template**:
`bucket/*.json.template`，安装 uv/pnpm/bun 等 interpreted-language app 的 manifest 蓝本，非具体 app。
_Avoid_: app 模板、模板 manifest、template manifest

**env-wrapper**:
`scripts/env-wrapper/` 下的通用 per-app wrapper（`.cmd` CLI / `.vbs` GUI），运行时读取 `app-env` 注入环境变量后委托 command-wrapper 逻辑执行命令。
_Avoid_: uv-env、per-manager wrapper

**app-env**:
installer 在 `$dir` 生成的 `app-env.cmd`，`set "KEY=%~dp0..."` 行形式声明该 app 的环境变量；wrapper 运行时从脚本自身位置推导路径。
_Avoid_: env 文件、env_set

**command-wrapper**:
`scripts/command-wrapper/` 下的共享包装脚本（`.cmd`/`.vbs`），从 PATH 解析候选命令、隐藏窗口运行并透传退出码；env-wrapper 复用其逻辑但不修改它。
