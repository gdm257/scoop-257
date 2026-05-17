# winswctl - Windows Services 中心化管理工具

## Goal

通过 winsw + task(taskfile) 构建一套轻量级的 Windows Services 中心化管理方案，作为独立 scoop 包 `winswctl` 分发。弥补 winsw 单实例只能管理单个服务的缺陷，通过 `winswctl` 命令对多个 winsw 服务进行统一安装/卸载/启停/状态查看，模拟 systemd 的中心化管理体验。

## Decisions

* **独立包**: `winswctl` 作为独立 scoop manifest，不再修改原 winsw 包
  * Why: 职责分离，winsw 包保持纯净，winswctl 按需安装
  * 通过 `depends: ["main/task"]` 声明 task 依赖

* **Taskfile.yml 位置**: 随 scoop 包安装到应用目录 (`~/scoop/apps/winswctl/current/Taskfile.yml`)
  * Why: 与 winswctl 打包在一起，版本同步更新
  * winswctl.ps1 wrapper 通过 `$PSScriptRoot` 定位 Taskfile

* **服务配置方式**: winsw 原生 YAML 配置
  * Why: 用户直接在 shims/ 下写标准 winsw yml 配置，工具只负责复制 exe + 注册服务
  * `add:*` 生成带 `$schema` 的 yml 模板，编辑器自动加载 JSON Schema 提供补全

* **MVP 范围**: 核心 CRUD + 基本健壮性（前置检查），不含升级清理

## Requirements

### UX - 命令设计

**文件层操作**（管理 shims/ 目录中的 exe + 配置）:
* `winswctl add:<svc>` — 复制 winsw.exe 到 shims/<svc>.exe + 创建初始 <svc>.yml 配置（含 $schema）
* `winswctl remove:<svc>` — 删除 shims/<svc>.exe + shims/<svc>.yml（文件级清理）
* `winswctl edit:<svc>` — 使用默认编辑器打开服务配置文件

**服务注册层操作**（Windows Service Manager）:
* `winswctl install:<svc>` — 注册服务（调用 shims/<svc>.exe install）
* `winswctl uninstall:<svc>` — 注销服务（调用 shims/<svc>.exe uninstall）

**服务控制**:
* `winswctl start:<svc>` — 启动服务
* `winswctl stop:<svc>` — 停止服务
* `winswctl restart:<svc>` — 重启服务

**查询**:
* `winswctl list` — 列出所有服务（shims/ 下的服务名）
* `winswctl status` — 查看所有服务状态（带服务名前缀）
* `winswctl status:<svc>` — 查看单个服务状态

**批量操作**:
* `winswctl start` — 启动所有服务
* `winswctl stop` — 停止所有服务
* `winswctl restart` — 重启所有服务

**典型用户流程**:
```
winswctl add:myapp          # 复制 exe + 创建初始 yml（含 $schema）
winswctl edit:myapp         # 用编辑器打开配置
winswctl install:myapp      # 注册为 Windows 服务
winswctl start:myapp        # 启动
winswctl status:myapp       # 查看状态
winswctl stop:myapp         # 停止
winswctl uninstall:myapp    # 注销服务
winswctl remove:myapp       # 清理文件
```

### 健壮性

* `add:<svc>` 前置检查: shims/<svc>.exe 是否已存在（避免覆盖）
* `remove:<svc>` 前置检查: shims/<svc>.exe 是否存在
* `install:<svc>` 前置检查: shims/<svc>.exe 是否存在
* `start:<svc>` / `stop:<svc>` / `restart:<svc>` 前置检查: shims/<svc>.exe 是否存在
* 错误时输出有意义的提示到 stderr

### Scoop 包设计

* **独立 manifest**: `bucket/winswctl.json`
  * 下载 winsw.exe（重命名为 winsw.exe）
  * `depends: ["main/task"]` 声明依赖
  * `installer` 从 bucket scripts 目录复制 Taskfile.yml + winswctl.ps1
  * `bin: [["winswctl.ps1", "winswctl"]]` 创建命令别名
  * `persist: ["shims"]` + `env_add_path: ["shims"]`
  * `checkver: "github"` + `autoupdate` 自动跟踪 winsw 版本

### 交付物

1. `bucket/winswctl.json` — 独立 scoop manifest
2. `scripts/winsw/Taskfile.yml` — task 任务定义
3. `scripts/winsw/winswctl.ps1` — wrapper 脚本

## Acceptance Criteria

* [x] `scoop install winswctl` 后 `winswctl` 命令可用
* [x] `winswctl add:<svc>` 复制 exe 并创建含 $schema 的 yml 配置
* [x] `winswctl edit:<svc>` 能打开编辑器编辑配置
* [x] `winswctl list` 列出所有服务
* [x] `winswctl install:<svc>` / `uninstall:<svc>` 能注册/注销服务
* [x] `winswctl start:<svc>` / `stop:<svc>` / `restart:<svc>` 能控制服务
* [x] `winswctl status` / `status:<svc>` 能查看服务状态（带服务名前缀）
* [x] `winswctl remove:<svc>` 能删除 exe + 配置文件
* [x] 操作前置条件不满足时，输出有意义的错误提示
* [x] winswctl.json 符合 scoop schema

## Definition of Done

* winswctl.json manifest 符合 scoop schema
* 手动测试核心流程: add -> edit config -> install -> start -> status -> stop -> uninstall -> remove
* 单一 squashed commit: `1b60366`

## Out of Scope

* scoop update winswctl 后批量更新已安装服务的 exe
* scoop uninstall winswctl 前自动 stop+uninstall 所有服务
* 日志查看/管理
* 服务开机自启/延迟启动等高级配置

## Technical Notes

* task CLI 使用 mvdan/sh (POSIX shell)，不是 PowerShell — Taskfile 中所有命令必须用 sh 语法
* task `silent: true` 全局设置避免打印命令源码
* task 通配符任务名 `start:*` 捕获服务名到 `.MATCH[0]`
* winsw 配置必须与 exe 同名同目录
* winsw 支持 YAML 配置格式，`$schema` 字段让编辑器自动加载 JSON Schema
* winsw v2.8+ 内置 UAC 自动提权
* scoop installer 中使用 `$bucketsdir` + `$bucket` 变量定位 bucket scripts
* wrapper 使用 `#!/usr/bin/env powershell` shebang

## Research References

* `research/winsw-xml-config.md` -- winsw XML/YAML 配置格式完整参考
* `research/taskfile-capabilities.md` -- taskfile.dev 能力完整调研
