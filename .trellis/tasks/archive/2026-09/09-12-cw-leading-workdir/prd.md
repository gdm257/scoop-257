# PRD: command-wrapper 允许前导 `--workdir`

## 背景

command-wrapper 目前只拦截**尾部**的 `--workdir <path>`（位于候选列表之后的转发参数里）。用户希望 `--workdir` 也可以出现在候选列表**之前**，便于统一书写顺序：`command-wrapper --workdir path cand1+cand2 [args...]`。

## 需求

1. 三个入口（`scripts/command-wrapper/command-wrapper.ps1` / `.cmd` / `.vbs`）行为一致：
   - 支持前导形式 `command-wrapper --workdir <path> <candidates> [args...]`
   - 保留现有尾部形式 `command-wrapper <candidates> [args...] [--workdir <path>]`
   - `--workdir` 整体保持可选
2. 前导 `--workdir` 缺值（后面没有参数）→ 报 `command-wrapper: --workdir requires a value`，退出码 1
3. 前导 `--workdir <path>` 之后没有候选列表 → 报现有的 `no candidates provided`，退出码 1
4. 相对路径解析规则不变：相对 `--workdir` 解析到脚本所在目录
5. 同步更新 `bucket/command-wrapper.json` 的 `description` 与三个脚本头部注释中的用法说明

## 非目标

- 不改变候选列表语法（`+` / `,` 分隔）
- 不支持多个 `--workdir`（前后同时出现时行为：后出现者覆盖前者即可，不专门报错）

## 验收标准

- `command-wrapper.cmd --workdir <dir> cand [args]` 与 `command-wrapper.cmd cand [args] --workdir <dir>` 均以 `<dir>` 为工作目录运行 `cand`
- 不带 `--workdir` 的旧用法完全不变
- `--workdir` 缺值 / 缺候选列表的错误路径覆盖三个入口
