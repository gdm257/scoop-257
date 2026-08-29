# 优化 bucket checkver 自动更新

## Goal

让 `bucket` 中因 GitHub tag 前缀、仓库指向或下载页结构变化而失败的 `checkver` 恢复可检测，并保证检测出的 version 与现有 URL 的版本段一致。

## Requirements

- 依据已确认的 Scoop 行为：`checkver: "github"` 默认只匹配 `v3.9.8` / `V3.9.8`，不能匹配 `agent-v3.9.8` 等带额外前缀的 tag。
- 为 tag 前缀不符合默认规则的 manifest 添加明确 `regex`。
- 为 `homepage` 带 query 或不是 GitHub 仓库的 manifest 显式指定 `checkver.github`。
- 为 latest release 不适用但 tags/releases 列表可判定的项目改用可过滤的 `checkver.url`。
- 修正 `listary5` 下载页新 DOM 对应的 regex。
- 修正 `autoupdate.url` 中不能由 checkver 结果正确生成的 `$version` / match 变量模板。
- 不把已失效上游伪装成可更新；`WinDeckHelper`、`git-ssh-sign` 和 `softalk` 保持现状并在验收中说明。
- `onscripter-ru` 无 `autoupdate`，现有下载 URL 含不可由版本推导的 `untagged-<hash>`，保持现状。
- 除 URL 模板纠错外，只修改 `checkver` / `autoupdate` 模板，不同步升级版本或下载 URL。

## Acceptance Criteria

- [x] 静态模拟 Scoop 变量替换后，`autoupdate.url` 能生成与当前 URL 版本形态一致的地址；需要前缀的 URL 保留前缀形态。
- [x] JSON 语法与 bucket 现有格式保持一致。
- [x] `WinDeckHelper`、`git-ssh-sign`、`softalk` 的失败能归因为上游无 release/tag 或站点 502，而非 regex 配置错误。

## Notes

- 旧结论来自 session `01a04d53-0b0d`：默认 GitHub regex 是 `/releases/tag/(?:v|V)?([\d.]+)`。
- 静态渲染例外：`dango-translator` 当前 URL 是旧 `Ver4.5.8` 格式，模板已按新 `Ver.$version` 格式修正；`ehentai-qt` 的模板形态正确，仅 manifest `version` 落后于当前 URL。
