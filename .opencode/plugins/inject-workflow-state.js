/* global process */
/**
 * Trellis Workflow State Injection Plugin
 *
 * Per-turn UserPromptSubmit equivalent for OpenCode.
 *
 * On every chat.message, if a Trellis task is active, inject a short
 * <workflow-state> breadcrumb reminding the main AI what task is active
 * and its expected flow. Breadcrumb text is pulled from the project's
 * workflow.md [workflow-state:STATUS] tag blocks (single source of
 * truth for users who fork the Trellis workflow), with hardcoded
 * fallbacks so the hook never breaks when workflow.md is missing or
 * malformed.
 *
 * Unlike session-start, this plugin does NOT dedupe — breadcrumb
 * should surface on every turn so long conversations don't drift.
 *
 * Silently skips when:
 *   - No .trellis/ directory
 *   - No active task in the session runtime context
 *   - task.json malformed or missing status
 */

import { existsSync, readFileSync } from "fs"
import { join } from "path"
import { TrellisContext, debugLog } from "../lib/trellis-context.js"

// Supports STATUS values with letters, digits, underscores, hyphens
// (so "in-review" / "blocked-by-team" work alongside "in_progress").
const TAG_RE = /\[workflow-state:([A-Za-z0-9_-]+)\]\s*\n([\s\S]*?)\n\s*\[\/workflow-state:\1\]/g

// Hardcoded defaults for built-in Trellis statuses. Used when workflow.md
// is missing, malformed, or lacks the tag for this status.
//
// `no_task` is a pseudo-status emitted when no session active task exists — keeps
// the Next-Action reminder flowing per-turn even without an active task.
const FALLBACK_BREADCRUMBS = {
  no_task:
    "No active task.\n" +
    "Trigger words in the user message that suggest creating a task: " +
    "重构 / 抽成 / 独立 / 分发 / 拆出来 / 搞一个 / 做成 / 接入 / 集成 / " +
    "refactor / rewrite / extract / productize / publish / build X / design Y.\n" +
    "Task is NOT required if ALL three hold: (a) zero file writes this turn, " +
    "(b) answer fits in one reply with no multi-round plan, (c) no research " +
    "beyond reading 1-2 repo files.\n" +
    "When in doubt and no override below applies: prefer creating a task — " +
    "over-tasking is cheap; under-tasking leaks plans and research into " +
    "main context.\n" +
    "Flow: load `trellis-brainstorm` skill → it creates the task via " +
    "`python3 ./.trellis/scripts/task.py create` and drives requirements Q&A. " +
    "For research-heavy work (tool comparison, docs, cross-platform survey), " +
    "spawn `trellis-research` sub-agents via Task tool — NEVER do 3+ inline " +
    "WebFetch/WebSearch/`gh api` calls in the main conversation.\n" +
    "User override (per-turn escape hatch): if the user's CURRENT message " +
    "contains an explicit opt-out phrase (\"跳过 trellis\" / \"别走流程\" / " +
    "\"小修一下\" / \"直接改\" / \"先别建任务\" / \"skip trellis\" / " +
    "\"no task\" / \"just do it\" / \"don't create a task\"), honor it for " +
    "this turn — briefly acknowledge (\"好，本轮跳过 trellis 流程\") and " +
    "proceed without creating a task. Per-turn only; does not carry forward; " +
    "do NOT invent an override the user did not say.",
  planning:
    "Complete prd.md via trellis-brainstorm skill; then run task.py start.\n" +
    "Research belongs in `{task_dir}/research/*.md`, written by " +
    "`trellis-research` sub-agents. Do NOT inline WebFetch/WebSearch in " +
    "main session — PRD only links to research files.",
  in_progress:
    "Flow: trellis-implement → trellis-check → trellis-update-spec → finish\n" +
    "Next required action: inspect conversation history + git status, then " +
    "execute the next uncompleted step in that sequence.\n" +
    "For agent-capable platforms, the default is to dispatch " +
    "`trellis-implement` for implementation and `trellis-check` before " +
    "reporting completion — do not edit code in the main session by default.\n" +
    "Use the exact Trellis agent type names when spawning sub-agents: " +
    "`trellis-implement`, `trellis-check`, or `trellis-research`. " +
    "Generic/default/generalPurpose sub-agents do not receive " +
    "`implement.jsonl` / `check.jsonl` injection.\n" +
    "User override (per-turn escape hatch): if the user's CURRENT message " +
    "explicitly tells the main session to handle it directly (\"你直接改\" / " +
    "\"别派 sub-agent\" / \"main session 写就行\" / \"do it inline\" / " +
    "\"不用 sub-agent\"), honor it for this turn and edit code directly. " +
    "Per-turn only; does not carry forward; do NOT invent an override the " +
    "user did not say.",
  completed:
    "Code committed via Phase 3.4; run `/trellis:finish-work` to wrap up " +
    "(archive task + record session).\n" +
    "If you reach this state with uncommitted code, return to Phase 3.4 " +
    "first — `/finish-work` refuses to run on a dirty working tree.\n" +
    "`task.py archive` deletes runtime session files that point at the " +
    "archived task.",
}

/**
 * Parse workflow.md for [workflow-state:STATUS] blocks.
 * Returns {status: body}. Missing tags fall back to hardcoded defaults.
 */
function loadBreadcrumbs(directory) {
  const result = { ...FALLBACK_BREADCRUMBS }
  const workflowPath = join(directory, ".trellis", "workflow.md")
  if (!existsSync(workflowPath)) return result
  let content
  try {
    content = readFileSync(workflowPath, "utf-8")
  } catch {
    return result
  }
  for (const match of content.matchAll(TAG_RE)) {
    const status = match[1]
    const body = match[2].trim()
    if (body) result[status] = body
  }
  return result
}

/**
 * Get (taskId, status) from active task, or null if no active task.
 */
function getActiveTask(ctx, platformInput = null) {
  const active = ctx.getActiveTask(platformInput)
  const taskRef = active.taskPath
  if (!taskRef) return null
  const taskDir = ctx.resolveTaskDir(taskRef)
  if (active.stale || !taskDir || !existsSync(taskDir)) {
    return { id: taskRef.split("/").pop(), status: "stale", source: active.source }
  }
  const taskJsonPath = join(taskDir, "task.json")
  if (!existsSync(taskJsonPath)) return null
  try {
    const data = JSON.parse(readFileSync(taskJsonPath, "utf-8"))
    const status = typeof data.status === "string" ? data.status : ""
    if (!status) return null
    const id = data.id || taskRef.split("/").pop()
    return { id, status, source: active.source }
  } catch {
    return null
  }
}

/**
 * Build the <workflow-state>...</workflow-state> block.
 * - Known status (templates or fallback) → detailed body
 * - Unknown status → generic "refer to workflow.md"
 * - no_task pseudo-status (id === null) → header omits task info
 */
function buildBreadcrumb(id, status, templates, source = null) {
  let body = templates[status]
  if (body === undefined) {
    body = "Refer to workflow.md for current step."
  }
  let header = id === null ? `Status: ${status}` : `Task: ${id} (${status})`
  if (source) {
    header = `${header}\nSource: ${source}`
  }
  return `<workflow-state>\n${header}\n${body}\n</workflow-state>`
}

// OpenCode 1.2.x expects plugins to be factory functions (see inject-subagent-context.js comment).
export default async ({ directory }) => {
  const ctx = new TrellisContext(directory)
  debugLog("workflow-state", "Plugin loaded, directory:", directory)

  return {
      // chat.message fires on every user message. Inject breadcrumb in-place
      // so it persists in conversation history.
      "chat.message": async (input, output) => {
        try {
          if (process.env.OPENCODE_NON_INTERACTIVE === "1") {
            return
          }
          if (!ctx.isTrellisProject()) {
            return
          }
          const templates = loadBreadcrumbs(directory)
          const task = getActiveTask(ctx, input)
          const breadcrumb = task
            ? buildBreadcrumb(task.id, task.status, templates, task.source)
            : buildBreadcrumb(null, "no_task", templates)

          const parts = output?.parts || []
          const textPartIndex = parts.findIndex(
            p => p.type === "text" && p.text !== undefined,
          )
          if (textPartIndex !== -1) {
            const originalText = parts[textPartIndex].text || ""
            parts[textPartIndex].text = `${breadcrumb}\n\n${originalText}`
          } else {
            parts.unshift({ type: "text", text: breadcrumb })
          }
          debugLog(
            "workflow-state",
            "Injected breadcrumb for task",
            task ? task.id : "none",
            "status",
            task ? task.status : "no_task",
          )
        } catch (error) {
          debugLog(
            "workflow-state",
            "Error in chat.message:",
            error instanceof Error ? error.message : String(error),
          )
        }
      },
  }
}
