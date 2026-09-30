# CONTEXT

Scoop bucket 领域术语表。

## checkver

manifest 中检测上游最新版本的配置。有两种互不兼容的匹配模式：

- **API 模式**：环境中存在 `GITHUB_TOKEN`（如 excavator CI）时，`checkver: github` 简写走 GitHub API，自定义 regex 只匹配**裸 `tag_name`**。任何 HTML 锚（`releases/tag/…`、`<title>`、资产文件名）在此模式下永远失配。
- **HTML 模式**：无 token 时抓取 releases 页面 HTML，regex 匹配整页源码，HTML 锚才有效。

写 regex 前必须先确定 bucket 主要运行环境（excavator = API 模式）。同一 regex 很难两全。

## tag_name / release name

上游的"版本"可能出现在两处：Git tag（`tag_name`）或 release 标题（name）。有的项目 tag 是 `26` 或 `untagged-<hash>`，真实版本只在 release name 里——此时 checkver 需显式 URL + 匹配 name 的 regex。

## autoupdate

按模板用新版本号拼出 URL 与 hash 提取方式、自动改写 manifest 的配置。checkver 与 autoupdate 的版本捕获组（含命名组）是上下游关系，改 regex 时不得破坏。

## 默认 regex 的破折号缺陷

`checkver: github` 不带自定义 regex 时默认 `(?:v|V)?([\d.-]+)`，遇 `v1.4.0-rc.1` 会产出畸形版本 `1.4.0-`。凡上游存在 prerelease tag 的 manifest 必须显式写 regex。

## deprecated/

死上游 manifest 的归档目录（区别于删除）：已安装用户仍可追溯。上游仓库消失、安装资产 404 且无合格继任者时使用。

## excavator

定时跑 `scoop checkver` + autoupdate 并提交版本更新 commit 的 GitHub Actions workflow，本 bucket 的主要运行环境（即 API 模式）。
