/**
 * generate_screen_docs.ts
 *
 * scenario-manifest.json + metadata.json + coverage-ledger.json から
 * 画面仕様ガイド (Markdown) を自動生成するスクリプト。
 *
 * 正本は screenshot_scenarios.ts（明示的シナリオ）と capture_screenshots.ts
 * が routes.rb から自動生成するシナリオ。本スクリプトは知識を持たず、
 * capture 実行後の成果物だけを読んで Markdown へ投影する。
 *
 * Usage:
 *   npx tsx script/generate_screen_docs.ts
 *
 * Output:
 *   docs/screen_guide.md
 *
 * 環境変数:
 *   SCREENSHOT_DIR  — scenario-manifest.json 等が置かれたディレクトリ（default: docs/screenshots）
 *   SCREEN_GUIDE_OUTPUT — 出力先（default: docs/screen_guide.md）
 */

import fs from "fs"
import path from "path"

// --- 型定義 ---

interface ManifestScenario {
  id: string
  screenName: string
  userStory: string
  outputName: string
  stateKind: string
  execution: string
  httpMethod: string
  actions: Array<{ type: string; selector: string; value?: string; description: string }>
  expectedBehavior?: string[]
  documentRole?: "primary" | "supplemental" | "exclude"
}

interface CoverageEntry {
  scenarioId: string
  outputName: string
  status: "captured" | "deferred" | "skipped" | "failed"
  reason?: string
  resumeCondition?: string
}

interface ScreenGroup {
  key: string
  label: string
  userStory: string
  screens: ScreenEntry[]
}

interface ScreenEntry {
  outputName: string
  file: string
  caption: string
  documentRole: "primary" | "supplemental" | "exclude"
  expectedBehavior: string[]
  status: "captured" | "deferred" | "skipped" | "failed"
}

// --- 設定 ---

const SCREENSHOTS_DIR = path.resolve(process.env.SCREENSHOT_DIR || "docs/screenshots")
const OUTPUT_FILE = path.resolve(process.env.SCREEN_GUIDE_OUTPUT || "docs/screen_guide.md")

type Section = "admin" | "public" | "system"

interface ScreenOrderEntry {
  key: string
  section: Section
}

// 表示順を固定したい画面のプレフィックスを定義。
// ここに含まれない画面は自動的に末尾に追加される。
const SCREEN_ORDER: ScreenOrderEntry[] = [
  // 認証・公開側
  { key: "session-new", section: "public" },
  { key: "dashboard-external", section: "public" },
  { key: "projects-show-tree", section: "public" },
  // 管理画面
  { key: "admin-dashboard", section: "admin" },
  { key: "admin-diagnostics", section: "admin" },
  { key: "admin-documents", section: "admin" },
  { key: "admin-projects", section: "admin" },
  { key: "admin-document-permissions", section: "admin" },
  { key: "admin-document-sets", section: "admin" },
  { key: "admin-document-catalogs", section: "admin" },
  { key: "admin-companies", section: "admin" },
  { key: "admin-users", section: "admin" },
  { key: "admin-project-memberships", section: "admin" },
  { key: "admin-consent-terms", section: "admin" },
  { key: "admin-project-consent-settings", section: "admin" },
  { key: "admin-git-import-sources", section: "admin" },
  { key: "admin-git-import-runs", section: "admin" },
  { key: "admin-external-folder-sync-sources", section: "admin" },
  { key: "admin-microsoft-graph-connections", section: "admin" },
  { key: "admin-zip-imports", section: "admin" },
  { key: "admin-file-upload-dry-runs", section: "admin" },
  { key: "admin-bulk-edit-dry-runs", section: "admin" },
  // システム管理
  { key: "admin-webhook-endpoints", section: "system" },
  { key: "admin-webhook-deliveries", section: "system" },
  { key: "admin-access-logs", section: "system" },
  { key: "admin-access-requests", section: "system" },
  { key: "admin-document-usage-reports", section: "system" },
  { key: "admin-read-confirmations", section: "system" },
  { key: "admin-recurring-job-schedules", section: "system" },
  { key: "admin-generated-file-events", section: "system" },
  { key: "admin-generated-file-runs", section: "system" },
]

// --- ユーティリティ ---

function resolveDocumentRole(scenario: ManifestScenario): "primary" | "supplemental" | "exclude" {
  if (scenario.documentRole) return scenario.documentRole
  return scenario.stateKind === "default" ? "primary" : "supplemental"
}

function inferScreenKey(outputName: string, stateKind: string): string {
  const actionSuffixes = ["-index", "-new", "-edit", "-show"]
  for (const suffix of actionSuffixes) {
    if (outputName.endsWith(suffix)) return outputName.slice(0, -suffix.length)
  }
  if (stateKind !== "default") {
    const stateSuffixes = ["-validation-error", "-mobile", "-restricted", "-empty", "-processing"]
    for (const suffix of stateSuffixes) {
      if (outputName.endsWith(suffix)) return outputName.slice(0, -suffix.length)
    }
    const lastHyphen = outputName.lastIndexOf("-")
    if (lastHyphen > 0) return outputName.slice(0, lastHyphen)
  }
  return outputName
}

function inferActionCaption(outputName: string, screenKey: string): string {
  const ACTION_LABELS: Record<string, string> = {
    index: "一覧画面",
    new: "新規作成画面",
    edit: "編集画面",
    show: "詳細画面",
  }
  if (outputName === screenKey) return "メイン画面"
  const remainder = outputName.slice(screenKey.length + 1)
  if (ACTION_LABELS[remainder]) return ACTION_LABELS[remainder]
  for (const [action, label] of Object.entries(ACTION_LABELS)) {
    if (remainder.endsWith(`-${action}`)) {
      const nested = remainder.slice(0, -(action.length + 1))
      return `${nested} ${label}`
    }
  }
  const STATE_LABELS: Record<string, string> = {
    "validation-error": "入力エラー状態",
    mobile: "モバイル表示",
    restricted: "権限制限状態",
    empty: "空状態",
    processing: "処理中状態",
  }
  for (const [state, label] of Object.entries(STATE_LABELS)) {
    if (remainder === state || remainder.endsWith(`-${state}`)) return label
  }
  return remainder.replace(/-/g, " ")
}

function encodeAnchor(label: string): string {
  return label
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, "")
    .replace(/\s+/g, "-")
}

// --- メイン処理 ---

function main(): void {
  const manifestPath = path.join(SCREENSHOTS_DIR, "scenario-manifest.json")
  const coveragePath = path.join(SCREENSHOTS_DIR, "coverage-ledger.json")

  if (!fs.existsSync(manifestPath)) {
    console.error(`ERROR: ${manifestPath} not found. Run capture_screenshots.ts first.`)
    process.exitCode = 1
    return
  }

  const scenarios: ManifestScenario[] = JSON.parse(fs.readFileSync(manifestPath, "utf-8"))
  const coverageEntries: CoverageEntry[] = fs.existsSync(coveragePath)
    ? JSON.parse(fs.readFileSync(coveragePath, "utf-8"))
    : []

  const coverageByOutput = new Map<string, CoverageEntry>()
  for (const entry of coverageEntries) coverageByOutput.set(entry.outputName, entry)

  const pngFiles = new Set(
    fs.readdirSync(SCREENSHOTS_DIR).filter((f) => f.endsWith(".png")).map((f) => f.replace(/\.png$/, "")),
  )

  // シナリオをスクリーングループに集約
  const groupMap = new Map<string, { label: string; userStory: string; screens: ScreenEntry[] }>()

  for (const scenario of scenarios) {
    const docRole = resolveDocumentRole(scenario)
    if (docRole === "exclude") continue

    const screenKey = inferScreenKey(scenario.outputName, scenario.stateKind)
    const coverage = coverageByOutput.get(scenario.outputName)
    const status = coverage?.status ?? "captured"
    const hasImage = pngFiles.has(scenario.outputName)

    const entry: ScreenEntry = {
      outputName: scenario.outputName,
      file: hasImage ? `${scenario.outputName}.png` : "",
      caption: inferActionCaption(scenario.outputName, screenKey),
      documentRole: docRole,
      expectedBehavior: scenario.expectedBehavior ?? [],
      status,
    }

    const existing = groupMap.get(screenKey)
    if (existing) {
      existing.screens.push(entry)
      if (docRole === "primary" && existing.userStory !== scenario.userStory) {
        const existingHasPrimary = existing.screens.some(
          (s) => s !== entry && s.documentRole === "primary",
        )
        if (!existingHasPrimary) {
          existing.userStory = scenario.userStory
          existing.label = scenario.screenName.replace(/[（(].+[）)]$/, "").trim()
        }
      }
    } else {
      groupMap.set(screenKey, {
        label: scenario.screenName.replace(/[（(].+[）)]$/, "").trim(),
        userStory: scenario.userStory,
        screens: [entry],
      })
    }
  }

  // グループリストを構築
  const groups: ScreenGroup[] = []
  for (const [key, value] of groupMap) {
    value.screens.sort((a, b) => {
      if (a.documentRole === "primary" && b.documentRole !== "primary") return -1
      if (a.documentRole !== "primary" && b.documentRole === "primary") return 1
      return 0
    })
    groups.push({ key, ...value })
  }

  // セクション分類と並び替え
  const orderIndex = new Map<string, { index: number; section: Section }>()
  for (let i = 0; i < SCREEN_ORDER.length; i++) {
    orderIndex.set(SCREEN_ORDER[i].key, { index: i, section: SCREEN_ORDER[i].section })
  }

  function classifySection(key: string): Section {
    const entry = orderIndex.get(key)
    if (entry) return entry.section
    if (key.startsWith("admin-")) return "admin"
    return "public"
  }

  function sortKey(group: ScreenGroup): number {
    const entry = orderIndex.get(group.key)
    return entry ? entry.index : 9999
  }

  const publicGroups = groups.filter((g) => classifySection(g.key) === "public").sort((a, b) => sortKey(a) - sortKey(b))
  const adminGroups = groups.filter((g) => classifySection(g.key) === "admin").sort((a, b) => sortKey(a) - sortKey(b))
  const systemGroups = groups.filter((g) => classifySection(g.key) === "system").sort((a, b) => sortKey(a) - sortKey(b))

  // Markdown 出力
  const lines: string[] = []
  lines.push("# 画面仕様ガイド")
  lines.push("")
  lines.push("> このドキュメントは `npx tsx script/generate_screen_docs.ts` で自動生成されています。")
  lines.push("> 正本は `script/screenshot_scenarios.ts`（明示的シナリオ）と")
  lines.push("> `capture_screenshots.ts` が routes.rb から自動生成するシナリオです。")
  lines.push("> スクリーンショットは `docs/screenshots/` を参照しています。")
  lines.push("")
  lines.push("---")
  lines.push("")

  // 目次
  lines.push("## 目次")
  lines.push("")
  lines.push("### 公開側")
  lines.push("")
  for (const g of publicGroups) lines.push(`- [${g.label}](#${encodeAnchor(g.label)})`)
  lines.push("")
  lines.push("### 管理画面")
  lines.push("")
  for (const g of adminGroups) lines.push(`- [${g.label}](#${encodeAnchor(g.label)})`)
  lines.push("")
  lines.push("### システム管理")
  lines.push("")
  for (const g of systemGroups) lines.push(`- [${g.label}](#${encodeAnchor(g.label)})`)
  lines.push("")
  lines.push("---")
  lines.push("")

  function renderSection(title: string, sectionGroups: ScreenGroup[]): void {
    lines.push(`## ${title}`)
    lines.push("")
    for (const group of sectionGroups) renderGroup(group)
  }

  function renderGroup(group: ScreenGroup): void {
    lines.push(`### ${group.label}`)
    lines.push("")
    lines.push(`**用途:** ${group.userStory}`)
    lines.push("")

    for (const screen of group.screens) {
      lines.push(`#### ${screen.caption}`)
      lines.push("")

      if (screen.expectedBehavior.length > 0) {
        lines.push("**この画面での操作:**")
        lines.push("")
        for (const op of screen.expectedBehavior) lines.push(`- ${op}`)
        lines.push("")
      }

      if (screen.file) {
        const imgPath = `screenshots/${screen.file}`
        lines.push(`![${screen.caption}](${imgPath})`)
      } else if (screen.status === "deferred") {
        lines.push("> ⏳ このシナリオは未撮影です（deferred）")
      } else if (screen.status === "skipped") {
        lines.push("> ⚠️ このシナリオはスキップされました")
      }
      lines.push("")
    }
  }

  renderSection("公開側", publicGroups)
  renderSection("管理画面", adminGroups)
  renderSection("システム管理", systemGroups)

  // ファイル書き出し
  const content = lines.join("\n") + "\n"
  fs.writeFileSync(OUTPUT_FILE, content, "utf-8")

  const totalScreens = groups.reduce((sum, g) => sum + g.screens.length, 0)
  const primaryCount = groups.reduce((sum, g) => sum + g.screens.filter((s) => s.documentRole === "primary").length, 0)
  const supplementalCount = totalScreens - primaryCount
  console.log(`Generated: ${path.relative(process.cwd(), OUTPUT_FILE)}`)
  console.log(`  ${totalScreens} screens (${primaryCount} primary, ${supplementalCount} supplemental), ${groups.length} groups`)
}

main()
