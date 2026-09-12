# winstctl: IaC 式管理 Windows 计划任务

## Goal

新建 `scripts/winstctl/`，以 IaC 方式管理 Windows 计划任务：Task Scheduler XML 文件为
source of truth，提交进 git，通过 `task` + `yq` + Windows 自带 `schtasks` 同步到系统。
结构与命令风格对齐现有 `scripts/winswctl/`。

## Requirements

* `scripts/winstctl/{winstctl.ps1,Taskfile.yml,template.xml}`，结构对齐 winswctl
  * `winstctl.ps1` 薄包装：`task -t Taskfile.yml @args`
  * `Taskfile.yml` 全部命令跑在 task 自带 mvdan/sh，风格（错误处理、输出措辞、`:*` 单对象 + 批量双形式）与 winswctl 一致
* `tasks/*.xml` 为 IaC 状态，Task Scheduler XML 格式
* 任务名 = 文件名去扩展名
* 命令面：
  * 查询：`list`（枚举 tasks/*.xml，yq 提取命令等字段展示）、`status(:*)`（`schtasks /query`）
  * 文件层：`add:*`（template.xml 中 `__TASK__` 占位替换生成）、`edit:*`（EDITOR 或 notepad）
  * 同步：`apply(:*)` = `schtasks /create /f /tn <name> /xml <file>`（幂等覆盖）；`destroy(:*)` = `schtasks /delete /f /tn <name>`
  * 控制：`run:*`、`end:*`
  * 导入：`import:*` = `schtasks /query /tn <name> /xml` 落为 `tasks/<name>.xml`（IaC onboarding）
* `bucket/winstctl.json`：对齐 scoop-checkver（纯脚本 manifest 模式）+ winswctl（depends/bin/installer/persist），depends `main/task`、`main/yq`，persist `tasks`、`template.xml`
* apply 对空 `<Command>` 的模板给出可操作提示（schtasks 原生报错不可读）

## Acceptance Criteria

* [x] `winstctl add:demo` 生成 tasks/demo.xml；填入命令后 `winstctl apply:demo` 创建/更新计划任务
* [x] 重复 `apply` 幂等（不报错、状态一致）
* [x] `schtasks /query /tn demo` 能查到任务且命令与 XML 一致
* [x] `winstctl run:demo` 可触发执行；`winstctl destroy:demo` 删除任务
* [x] `import:*` 能把现存系统任务导出为 tasks/<name>.xml 并再次 apply 成功
* [x] `list`/`status` 对空目录、未注册任务给出与 winswctl 措辞一致的清晰输出
* [x] `scoop install gdm257/winstctl` 后 shim `winstctl` 全链路可用（add → 空命令守卫 → apply ×2 → run → destroy → remove）
* [x] 未编辑模板 `apply` 提示 `has an empty Command. Run 'winstctl edit:X' first.`

## Definition of Done

* 脚本风格与 winswctl 一致（sh 语法、错误处理、输出措辞）
* 本机实际 smoke test（add → apply → query → run → destroy → import → apply）

## Decision (ADR-lite)

**Context**: YAML→schtasks 有 flags 与 XML 两条路。
**Decision**: schtasks 原生支持 XML，配置直接用 XML（不经 YAML 转换）；yq 保留用于解析 XML（list 展示）。
**Consequences**: 全量 Task Scheduler 保真；不做 YAML 抽象层；导出的系统 XML 含运行时字段，不做 diff/prune，apply 一律 `/f` 覆盖。

## Out of Scope

* 不管理 Windows 服务（winswctl 已覆盖）
* 不做 prune（系统里存在但未声明的任务不自动删，避免误删系统任务）
* 不做 diff/漂移检测（导出 XML 含运行时字段，归一化成本高）
* 不做提权/凭据管理（`/ru /rp` 类参数由用户在 XML 中自行配置）
* 不做跨机同步

## Technical Notes

* 已读参考：`scripts/winswctl/{winswctl.ps1,Taskfile.yml,template.yml}`
* `schtasks /create /tn <name> /xml <file>` 为文档化组合，/tn 覆盖 XML 内 URI，故文件名即任务名可靠
* template.xml 需本机验证 schtasks 对 UTF-8 声明 XML 的接受度（Task Scheduler 常见 UTF-16，以 smoke test 为准）
* 本机为中文 Windows，schtasks /query 输出本地化，包装层只透传
