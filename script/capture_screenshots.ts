import { execFile } from "node:child_process"
import { createHash } from "node:crypto"
import fs from "node:fs/promises"
import path from "node:path"
import { promisify } from "node:util"
import { chromium, type Browser, type BrowserContext, type ConsoleMessage, type Page, type Response } from "playwright"
import {
  detectSecretPatterns,
  groupDuplicateImageHashes,
  isExpectedUrl,
  validateScenarioManifest,
  type ImageDigest,
  type ScreenshotScenario,
} from "../app/frontend/screenshot_audit"
import { desktopViewport, explicitScreenshotScenarios } from "./screenshot_scenarios"
import { scenarioFor } from "./screenshot_scenario_planner"
import {
  discoverResourcesFromRoutes,
  singularResourceGetPaths,
  type RouteResourceNode,
} from "./screenshot_route_parser"

const execFileAsync = promisify(execFile)
const APP_HOST = process.env.APP_HOST ?? "app"
const APP_PORT = process.env.APP_SERVER_PORT ?? process.env.APP_PORT ?? process.env.PORT ?? "3000"
const BASE_URL = process.env.APP_BASE_URL ?? `http://${APP_HOST}:${APP_PORT}`
const OUT_DIR = path.resolve(process.env.SCREENSHOT_DIR ?? path.join(process.cwd(), "tmp", "screenshots"))
const TIMINGS_OUTPUT = path.resolve(process.env.SCREENSHOT_TIMINGS_OUTPUT ?? path.join(path.dirname(OUT_DIR), "capture-timings.json"))
const ADMIN_EMAIL = process.env.SCREENSHOT_EMAIL ?? "admin@example.com"
const ADMIN_PASSWORD = process.env.SCREENSHOT_PASSWORD ?? "password123!"
const ROUTES_FILE = process.env.ROUTES_FILE ?? path.join(process.cwd(), "config", "routes.rb")
const LOCALE = process.env.SCREENSHOT_LOCALE ?? "ja-JP"
const TIMEZONE = process.env.SCREENSHOT_TIMEZONE ?? "Asia/Tokyo"
const DEBUG_SCREENSHOTS = process.env.DEBUG_SCREENSHOTS === "1"
const SCREENSHOT_CONCURRENCY = Math.min(
  8,
  Math.max(1, Number.parseInt(process.env.SCREENSHOT_CONCURRENCY ?? "4", 10) || 4),
)

// docs-portal では admin namespace 配下のリソースだけを自動発見対象にする
const AUTO_DISCOVER_NAMESPACE = "admin"
// show/new がないリソース（routes.rb で except: %i[show new] されている）は edit も探さない
const SKIP_TOPLEVEL_RESOURCES = new Set<string>([])
const VIEW_EXTENSIONS = [".html.slim", ".html.erb"]

class SkippedRedirectError extends Error {
  constructor(message: string) {
    super(message)
    this.name = "SkippedRedirectError"
  }
}

type ResourceNode = RouteResourceNode & { viewActions?: string[] }

interface CoverageEntry {
  scenarioId: string
  outputName: string
  userStory: string
  httpMethod: ScreenshotScenario["httpMethod"]
  stateKind: ScreenshotScenario["stateKind"]
  status: "captured" | "deferred" | "skipped" | "failed"
  reason?: string
  resumeCondition?: string
}

interface CaptureMetadata {
  scenarioId: string
  screenName: string
  userStory: string
  httpMethod: ScreenshotScenario["httpMethod"]
  prerequisites: string[]
  actions: ScreenshotScenario["actions"]
  stateKind: ScreenshotScenario["stateKind"]
  sourceRevision: string
  capturedAt: string
  locale: string
  timezone: string
  viewport: ScreenshotScenario["viewport"]
  role: ScreenshotScenario["role"]
  requestedUrl: string
  finalUrl: string
  outputName: string
  sha256: string
}

interface CaptureTiming {
  scenarioId: string
  outputName: string
  elapsedMs: number
  status: "captured" | "skipped" | "failed"
}

interface CaptureBatch {
  manifests: ScreenshotScenario[]
  metadata: CaptureMetadata[]
  coverage: CoverageEntry[]
}

interface CaptureTask {
  label: string
  fallbackScenario?: ScreenshotScenario
  run: (page: Page, audit: BrowserAudit, batch: CaptureBatch) => Promise<void>
}

const captureTimings: CaptureTiming[] = []

class BrowserAudit {
  private httpErrors: string[] = []
  private pageErrors: string[] = []
  private consoleErrors: string[] = []
  private readonly consoleAllowlist: RegExp[]

  constructor(private readonly page: Page) {
    const envPatterns = (process.env.SCREENSHOT_CONSOLE_ERROR_ALLOWLIST ?? "")
      .split(",")
      .map((pattern) => pattern.trim())
      .filter(Boolean)
      .map((pattern) => new RegExp(pattern))
    const defaultPatterns = [
      /Failed to fetch/,
      /Missing target element/,
      /Error connecting controller/,
    ]
    this.consoleAllowlist = [...defaultPatterns, ...envPatterns]

    page.on("response", (response: Response) => {
      if (response.status() >= 400) this.httpErrors.push(`${response.status()} ${response.url()}`)
    })
    page.on("pageerror", (error: Error) => {
      if (!this.consoleAllowlist.some((pattern) => pattern.test(error.message))) this.pageErrors.push(error.message)
    })
    page.on("console", (message: ConsoleMessage) => {
      if (message.type() !== "error") return
      const text = message.text()
      if (!this.consoleAllowlist.some((pattern) => pattern.test(text))) this.consoleErrors.push(text)
    })
  }

  reset(): void {
    this.httpErrors = []
    this.pageErrors = []
    this.consoleErrors = []
  }

  assertClean(scenarioId: string): void {
    const failures = [
      ...this.httpErrors.map((message) => `HTTP: ${message}`),
      ...this.pageErrors.map((message) => `pageerror: ${message}`),
      ...this.consoleErrors.map((message) => `console.error: ${message}`),
    ]
    if (failures.length > 0) throw new Error(`${scenarioId} browser audit failed:\n${failures.join("\n")}`)
  }
}

function skipMetadata(scenario: ScreenshotScenario, sourceRevision: string, finalUrl: string): CaptureMetadata {
  return {
    scenarioId: scenario.id,
    screenName: scenario.screenName,
    userStory: scenario.userStory,
    httpMethod: scenario.httpMethod,
    prerequisites: scenario.prerequisites,
    actions: scenario.actions,
    stateKind: scenario.stateKind,
    sourceRevision,
    capturedAt: new Date().toISOString(),
    locale: LOCALE,
    timezone: TIMEZONE,
    viewport: scenario.viewport,
    role: scenario.role,
    requestedUrl: scenario.url,
    finalUrl,
    outputName: scenario.outputName,
    sha256: "",
  }
}

function coverageFor(
  scenario: ScreenshotScenario,
  status: CoverageEntry["status"],
  reason?: string,
  resumeCondition?: string,
): CoverageEntry {
  return {
    scenarioId: scenario.id,
    outputName: scenario.outputName,
    userStory: scenario.userStory,
    httpMethod: scenario.httpMethod,
    stateKind: scenario.stateKind,
    status,
    reason,
    resumeCondition,
  }
}

function emptyCaptureBatch(): CaptureBatch {
  return { manifests: [], metadata: [], coverage: [] }
}

function canCaptureInParallel(scenario: ScreenshotScenario): boolean {
  return scenario.httpMethod === "GET" && scenario.actions.length === 0
}

async function templateExists(resource: ResourceNode, action: string): Promise<boolean> {
  const segments = [...resource.namespacePrefix, resource.name, action]
  const searchPaths = [path.join("app", "views")]
  for (const base of searchPaths) {
    for (const extension of VIEW_EXTENSIONS) {
      try {
        await fs.access(`${path.join(process.cwd(), base, ...segments)}${extension}`)
        return true
      } catch {
        // next
      }
    }
  }
  return false
}

async function annotateResourcesWithViews(resources: ResourceNode[]): Promise<Array<ResourceNode & { viewActions: string[] }>> {
  const annotated: Array<ResourceNode & { viewActions: string[] }> = []
  for (const resource of resources) {
    const viewActions: string[] = []
    for (const action of resource.actions) if (await templateExists(resource, action)) viewActions.push(action)
    if (viewActions.length > 0) annotated.push({ ...resource, viewActions })
  }
  return annotated
}

async function waitForApp(page: Page): Promise<void> {
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    try {
      const response = await page.goto(`${BASE_URL}/session/new`, { waitUntil: "domcontentloaded" })
      if (response && response.status() < 500) return
    } catch (error) {
      if (attempt === 60) throw error
    }
    await page.waitForTimeout(2000)
  }
  throw new Error(`Application at ${BASE_URL} did not become ready.`)
}

async function waitForAuditReady(page: Page): Promise<void> {
  try {
    await page.waitForLoadState("networkidle", { timeout: 15000 })
  } catch (_e) {
    // networkidle タイムアウトは致命的ではない — 長時間接続や遅延フォントで発生し得る
  }
  try {
    await page.evaluate(async () => document.fonts.ready)
  } catch (_e) {
    // フォント読み込みタイムアウト — 撮影を続行
  }
  try {
    await page.waitForFunction(`(() => {
    const isVisible = (element) => {
      const rect = element.getBoundingClientRect();
      const style = window.getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 && rect.bottom >= 0 && rect.top <= window.innerHeight && style.display !== "none" && style.visibility !== "hidden";
    };
    const pendingTurboFrames = [...document.querySelectorAll("turbo-frame[busy], turbo-frame[aria-busy='true'], turbo-frame[src]:not([complete])")].filter(isVisible);
    const busyElements = [...document.querySelectorAll("[aria-busy='true']")].filter(isVisible);
    const loadingElements = [...document.querySelectorAll(".spinner-border, .spinner-grow")].filter(isVisible);
    const stimulus = window.Stimulus;
    const controllerElements = [...document.querySelectorAll("[data-controller]")].filter(isVisible);
    const stimulusReady = controllerElements.length === 0 || Boolean(stimulus) && controllerElements.every((element) =>
      (element.dataset.controller ?? "").split(/\\s+/).filter(Boolean).every((identifier) =>
        stimulus?.getControllerForElementAndIdentifier(element, identifier),
      ),
    );
    return pendingTurboFrames.length === 0 && busyElements.length === 0 && loadingElements.length === 0 && stimulusReady;
  })()`, { timeout: 15000 })
  } catch (_e) {
    // Stimulus controller 接続タイムアウト — Turbo/busy が解消されていれば続行
    try {
      await page.waitForFunction(`(() => {
      const isVisible = (element) => {
        const rect = element.getBoundingClientRect();
        const style = window.getComputedStyle(element);
        return rect.width > 0 && rect.height > 0 && style.display !== "none" && style.visibility !== "hidden";
      };
      const pendingTurboFrames = [...document.querySelectorAll("turbo-frame[busy], turbo-frame[aria-busy='true']")].filter(isVisible);
      const busyElements = [...document.querySelectorAll("[aria-busy='true']")].filter(isVisible);
      return pendingTurboFrames.length === 0 && busyElements.length === 0;
    })()`, { timeout: 10000 })
    } catch (_fallbackError) {
      // フォールバックもタイムアウト — 撮影は続行する（表示中のスナップショットで十分）
    }
  }
  await page.evaluate(() => new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))))
}

async function assertExpectedPage(page: Page, scenario: ScreenshotScenario): Promise<void> {
  if (!isExpectedUrl(page.url(), BASE_URL, scenario.url)) {
    const msg = `${scenario.id} unexpected redirect: expected ${scenario.url}, got ${page.url()}`
    console.warn(`WARN: ${msg} — skipping capture`)
    throw new SkippedRedirectError(msg)
  }
  for (const selector of scenario.expectedSelectors) await page.locator(selector).first().waitFor({ state: "visible", timeout: 15000 })
  await page.locator(scenario.expectedState.selector).first().waitFor({ state: "visible", timeout: 15000 })

  const railsError = await page.locator("body").evaluate((body) => {
    const text = body.textContent ?? ""
    return /Action Controller: Exception caught|Routing Error|ActiveRecord::|Application Trace|Rails root:/i.test(text)
  })
  if (railsError) throw new Error(`${scenario.id} rendered a Rails error page`)

  const auditableContent = await page.evaluate(() => {
    const values = [...document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>("input, textarea")]
      .map((field) => field.value)
      .filter(Boolean)
    return `${document.body.innerText}\n${location.href}\n${values.join("\n")}`
  })
  const secretFindings = detectSecretPatterns(auditableContent)
  if (secretFindings.length > 0) {
    throw new Error(`${scenario.id} contains rejected secret patterns: ${secretFindings.map((finding) => finding.pattern).join(", ")}`)
  }
}

async function performScenarioActions(page: Page, scenario: ScreenshotScenario): Promise<void> {
  for (const action of scenario.actions) {
    const target = page.locator(action.selector).first()
    await target.waitFor({ state: "visible", timeout: 15000 })
    if (action.type === "fill") await target.fill(action.value ?? "")
    else await target.click()
  }
}

async function navigateAndCapture(
  page: Page,
  audit: BrowserAudit,
  scenario: ScreenshotScenario,
  sourceRevision: string,
): Promise<CaptureMetadata> {
  const startedAt = Date.now()
  let timingStatus: CaptureTiming["status"] = "failed"

  try {
    const validationErrors = validateScenarioManifest([scenario])
    if (validationErrors.length > 0) throw new Error(validationErrors.join("\n"))
    if (scenario.execution !== "capture") throw new Error(`${scenario.id} is deferred and cannot be captured`)
    await page.setViewportSize({ width: scenario.viewport.width, height: scenario.viewport.height })
    audit.reset()
    const response = await page.goto(new URL(scenario.url, BASE_URL).toString(), { waitUntil: "domcontentloaded" })
    if (!response) throw new Error(`${scenario.id} navigation returned no HTTP response`)
    if (response.status() >= 400) throw new Error(`${scenario.id} navigation failed with HTTP ${response.status()}`)
    await waitForAuditReady(page)
    if (scenario.actions.length > 0) {
      await performScenarioActions(page, scenario)
      await waitForAuditReady(page)
    }
    try {
      await assertExpectedPage(page, scenario)
    } catch (e) {
      if (e instanceof SkippedRedirectError) {
        timingStatus = "skipped"
        return skipMetadata(scenario, sourceRevision, page.url())
      }
      throw e
    }
    audit.assertClean(scenario.id)

    const filePath = path.join(OUT_DIR, `${scenario.outputName}.png`)
    await page.screenshot({ path: filePath, fullPage: false })
    const sha256 = createHash("sha256").update(await fs.readFile(filePath)).digest("hex")
    console.log(`saved ${path.relative(process.cwd(), filePath)} (${scenario.id})`)
    timingStatus = "captured"
    return {
      scenarioId: scenario.id,
      screenName: scenario.screenName,
      userStory: scenario.userStory,
      httpMethod: scenario.httpMethod,
      prerequisites: scenario.prerequisites,
      actions: scenario.actions,
      stateKind: scenario.stateKind,
      sourceRevision,
      capturedAt: new Date().toISOString(),
      locale: LOCALE,
      timezone: TIMEZONE,
      viewport: scenario.viewport,
      role: scenario.role,
      requestedUrl: scenario.url,
      finalUrl: page.url(),
      outputName: scenario.outputName,
      sha256,
    }
  } finally {
    const elapsedMs = Date.now() - startedAt
    captureTimings.push({ scenarioId: scenario.id, outputName: scenario.outputName, elapsedMs, status: timingStatus })
    console.log(`[capture:${timingStatus}] ${(elapsedMs / 1000).toFixed(1)}s ${scenario.id}`)
  }
}

async function login(
  page: Page,
  audit: BrowserAudit,
  sourceRevision: string,
  captureGuestScenarios = true,
): Promise<CaptureMetadata[]> {
  await waitForApp(page)
  const metadata: CaptureMetadata[] = []

  if (captureGuestScenarios) {
    const guestScenarios = explicitScreenshotScenarios.filter(
      (scenario) => scenario.role === "guest" && scenario.execution === "capture",
    )
    for (const scenario of guestScenarios) {
      metadata.push(await navigateAndCapture(page, audit, scenario, sourceRevision))
    }
  }

  audit.reset()
  await page.goto(new URL("/session/new", BASE_URL).toString(), { waitUntil: "domcontentloaded" })
  await waitForAuditReady(page)
  await page.locator("input[type='email']").fill(ADMIN_EMAIL)
  await page.locator("input[type='password']").fill(ADMIN_PASSWORD)
  await Promise.all([
    page.waitForURL((url) => !url.toString().includes("/session/new"), { timeout: 30000 }),
    page.locator("input[type='submit'], button[type='submit']").click(),
  ])
  await waitForAuditReady(page)
  audit.assertClean("session.create.submit")
  if (page.url().includes("/session/new")) throw new Error("Login failed. Check screenshot credentials.")
  return metadata
}

async function findFirstRecordPath(page: Page, resource: ResourceNode): Promise<string | null> {
  const locator = page.locator(`main table tbody tr a[href*="${resource.basePath}/"]`)
  const count = await locator.count()
  for (let i = 0; i < count && i < 5; i += 1) {
    const href = await locator.nth(i).getAttribute("href")
    if (!href) continue

    const pathname = new URL(href, BASE_URL).pathname
    const cleaned = pathname.replace(/\/(edit|download|preview)$/, "")
    if (cleaned) return cleaned
  }
  return null
}

async function captureResource(
  page: Page,
  audit: BrowserAudit,
  resource: ResourceNode & { viewActions: string[] },
  sourceRevision: string,
  manifests: ScreenshotScenario[],
  metadata: CaptureMetadata[],
  coverage: CoverageEntry[],
  explicitOutputNames: Set<string>,
): Promise<void> {
  if (resource.singular) {
    for (const { action, path: scenarioPath } of singularResourceGetPaths(resource)) {
      if (!resource.viewActions.includes(action)) continue
      const scenario = scenarioFor(resource, action, scenarioPath)
      if (explicitOutputNames.has(scenario.outputName)) continue
      manifests.push(scenario)
      const result = await navigateAndCapture(page, audit, scenario, sourceRevision)
      metadata.push(result)
      coverage.push(result.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }
    return
  }

  if (resource.viewActions.includes("index")) {
    const scenario = scenarioFor(resource, "index", resource.basePath)
    if (!explicitOutputNames.has(scenario.outputName)) {
      manifests.push(scenario)
      const result = await navigateAndCapture(page, audit, scenario, sourceRevision)
      metadata.push(result)
      coverage.push(result.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }
  }

  if (resource.viewActions.includes("new")) {
    const scenario = scenarioFor(resource, "new", `${resource.basePath}/new`)
    if (!explicitOutputNames.has(scenario.outputName)) {
      manifests.push(scenario)
      const result = await navigateAndCapture(page, audit, scenario, sourceRevision)
      metadata.push(result)
      coverage.push(result.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }
  }

  // show / edit はレコードが必要
  if (!resource.viewActions.includes("show") && !resource.viewActions.includes("edit")) return
  if (!resource.viewActions.includes("index")) return

  audit.reset()
  const response = await page.goto(new URL(resource.basePath, BASE_URL).toString(), { waitUntil: "domcontentloaded" })
  if (!response?.ok()) return
  await waitForAuditReady(page)
  const showPath = await findFirstRecordPath(page, resource)
  if (!showPath) {
    for (const action of ["show", "edit"] as const) {
      if (!resource.viewActions.includes(action)) continue
      const scenario = scenarioFor(resource, action, resource.basePath, "first-record")
      manifests.push(scenario)
      coverage.push(coverageFor(scenario, "skipped", "一覧に対象レコードがない", "対象レコードをseedへ追加して再実行する"))
    }
    return
  }

  if (resource.viewActions.includes("show")) {
    const scenario = scenarioFor(resource, "show", showPath, "first-record")
    if (!explicitOutputNames.has(scenario.outputName)) {
      manifests.push(scenario)
      const result = await navigateAndCapture(page, audit, scenario, sourceRevision)
      metadata.push(result)
      coverage.push(result.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }
  }

  if (resource.viewActions.includes("edit")) {
    const scenario = scenarioFor(resource, "edit", `${showPath}/edit`, "first-record")
    if (!explicitOutputNames.has(scenario.outputName)) {
      manifests.push(scenario)
      const result = await navigateAndCapture(page, audit, scenario, sourceRevision)
      metadata.push(result)
      coverage.push(result.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }
  }
}

async function getSourceRevision(): Promise<string> {
  if (process.env.SOURCE_REVISION) return process.env.SOURCE_REVISION
  try {
    const [{ stdout: revision }, { stdout: status }] = await Promise.all([
      execFileAsync("git", ["rev-parse", "HEAD"], { cwd: process.cwd() }),
      execFileAsync("git", ["status", "--porcelain"], { cwd: process.cwd() }),
    ])
    return `${revision.trim()}${status.trim() ? "+dirty" : ""}`
  } catch {
    return "unknown"
  }
}

async function createBrowserPage(browser: Browser): Promise<{ context: BrowserContext; page: Page; audit: BrowserAudit }> {
  const context = await browser.newContext({
    viewport: desktopViewport,
    deviceScaleFactor: 1,
    locale: LOCALE,
    timezoneId: TIMEZONE,
  })
  const page = await context.newPage()
  page.setDefaultNavigationTimeout(60000)
  page.setDefaultTimeout(30000)
  return { context, page, audit: new BrowserAudit(page) }
}

async function runCaptureTasks(
  browser: Browser,
  sourceRevision: string,
  tasks: CaptureTask[],
): Promise<{ batches: CaptureBatch[]; errors: Error[] }> {
  if (tasks.length === 0) return { batches: [], errors: [] }

  const workerCount = Math.min(SCREENSHOT_CONCURRENCY, tasks.length)
  const batches: Array<CaptureBatch | undefined> = new Array(tasks.length)
  const errors: Error[] = []
  let nextTaskIndex = 0

  console.log(`screenshot capture: ${tasks.length} task(s), ${workerCount} worker(s)`)

  await Promise.all(Array.from({ length: workerCount }, async (_, workerIndex) => {
    const { context, page, audit } = await createBrowserPage(browser)
    try {
      try {
        await login(page, audit, sourceRevision, false)
      } catch (error: unknown) {
        errors.push(new Error(`screenshot worker ${workerIndex + 1} login failed: ${error instanceof Error ? error.message : String(error)}`))
        return
      }

      while (true) {
        const taskIndex = nextTaskIndex
        nextTaskIndex += 1
        if (taskIndex >= tasks.length) break

        const task = tasks[taskIndex]
        const batch = emptyCaptureBatch()
        try {
          if (DEBUG_SCREENSHOTS) console.log(`worker ${workerIndex + 1}: ${task.label}`)
          await task.run(page, audit, batch)
        } catch (error: unknown) {
          const failedScenario = [...batch.manifests].reverse().find(
            (scenario) => scenario.execution === "capture" && !batch.coverage.some((entry) => entry.scenarioId === scenario.id),
          ) ?? task.fallbackScenario
          if (failedScenario && !batch.coverage.some((entry) => entry.scenarioId === failedScenario.id)) {
            batch.coverage.push(coverageFor(
              failedScenario,
              "failed",
              error instanceof Error ? error.message : String(error),
              "失敗原因を修正して同じsource revisionで再実行する",
            ))
          }
          errors.push(new Error(`${task.label}: ${error instanceof Error ? error.message : String(error)}`))
        } finally {
          batches[taskIndex] = batch
        }
      }
    } finally {
      await context.close()
    }
  }))

  return { batches: batches.filter((batch): batch is CaptureBatch => Boolean(batch)), errors }
}

function printCaptureTimingSummary(): void {
  const slowest = [...captureTimings].sort((a, b) => b.elapsedMs - a.elapsedMs).slice(0, 10)
  if (slowest.length === 0) return
  console.log("\nSlowest screenshots:")
  for (const timing of slowest) {
    console.log(`  ${(timing.elapsedMs / 1000).toFixed(1).padStart(6)}s  ${timing.status.padEnd(8)}  ${timing.scenarioId}`)
  }
}

async function writeAuditArtifacts(
  manifests: ScreenshotScenario[],
  metadata: CaptureMetadata[],
  coverage: CoverageEntry[],
): Promise<void> {
  const validationErrors = validateScenarioManifest(manifests)
  if (validationErrors.length > 0) throw new Error(`scenario manifest is invalid:\n${validationErrors.join("\n")}`)

  const coverageIds = new Set(coverage.map((entry) => entry.scenarioId))
  const missingCoverage = manifests.filter((scenario) => !coverageIds.has(scenario.id))
  const untraceableCoverage = coverage.filter(
    (entry) => entry.status !== "captured" && (!entry.reason?.trim() || !entry.resumeCondition?.trim()),
  )
  if (missingCoverage.length > 0 || untraceableCoverage.length > 0) {
    throw new Error([
      ...missingCoverage.map((scenario) => `coverage is missing: ${scenario.id}`),
      ...untraceableCoverage.map((entry) => `coverage reason or resume condition is missing: ${entry.scenarioId}`),
    ].join("\n"))
  }

  const digests: ImageDigest[] = metadata.map((entry) => ({ outputName: entry.outputName, sha256: entry.sha256 }))
  const duplicateGroups = groupDuplicateImageHashes(digests)
  const timingReport = [...captureTimings].sort((a, b) => b.elapsedMs - a.elapsedMs)

  await Promise.all([
    fs.writeFile(path.join(OUT_DIR, "scenario-manifest.json"), `${JSON.stringify(manifests, null, 2)}\n`),
    fs.writeFile(path.join(OUT_DIR, "coverage-ledger.json"), `${JSON.stringify(coverage, null, 2)}\n`),
    fs.writeFile(path.join(OUT_DIR, "metadata.json"), `${JSON.stringify(metadata, null, 2)}\n`),
    fs.writeFile(path.join(OUT_DIR, "duplicate-image-report.json"), `${JSON.stringify({ suspectedDuplicates: duplicateGroups }, null, 2)}\n`),
    fs.writeFile(TIMINGS_OUTPUT, `${JSON.stringify({ concurrency: SCREENSHOT_CONCURRENCY, screenshots: timingReport }, null, 2)}\n`),
  ])

  if (duplicateGroups.length > 0) console.warn(`duplicate image hashes suspected: ${duplicateGroups.length} group(s)`)

  const skippedCoverage = coverage.filter((entry) => entry.status === "skipped")
  const failedCoverage = coverage.filter((entry) => entry.status === "failed")
  if (skippedCoverage.length > 0 || failedCoverage.length > 0) {
    throw new Error([
      ...skippedCoverage.map((entry) => `skipped (seed不足またはリダイレクト): ${entry.scenarioId} — ${entry.reason}`),
      ...failedCoverage.map((entry) => `failed: ${entry.scenarioId} — ${entry.reason}`),
    ].join("\n"))
  }
}

async function main(): Promise<void> {
  await fs.mkdir(OUT_DIR, { recursive: true })
  const existingEntries = await fs.readdir(OUT_DIR, { withFileTypes: true })
  await Promise.all(existingEntries.filter((entry) => entry.isFile()).map((entry) => fs.unlink(path.join(OUT_DIR, entry.name))))

  const revision = await getSourceRevision()
  const allResources = await discoverResourcesFromRoutes(ROUTES_FILE)
  // admin namespace 配下のリソースだけを自動発見対象にする
  const adminResources = allResources.filter((r) => r.namespacePrefix.includes(AUTO_DISCOVER_NAMESPACE) && !r.parentKey)
  const resources = await annotateResourcesWithViews(adminResources.filter((r) => !SKIP_TOPLEVEL_RESOURCES.has(r.name)))

  const manifests: ScreenshotScenario[] = [...explicitScreenshotScenarios]
  const metadata: CaptureMetadata[] = []
  const coverage: CoverageEntry[] = manifests
    .filter((scenario) => scenario.execution === "deferred")
    .map((scenario) => coverageFor(
      scenario,
      "deferred",
      scenario.deferral?.reason,
      scenario.deferral?.resumeCondition,
    ))

  const browser = await chromium.launch({ headless: true })
  const coordinator = await createBrowserPage(browser)
  let captureError: unknown

  try {
    const guestMetadata = await login(coordinator.page, coordinator.audit, revision)
    metadata.push(...guestMetadata)
    for (const entry of guestMetadata) {
      const scenario = manifests.find((candidate) => candidate.id === entry.scenarioId)
      if (scenario) coverage.push(entry.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${entry.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }

    const adminScenarios = explicitScreenshotScenarios.filter(
      (scenario) => scenario.role === "admin" && scenario.execution === "capture",
    )
    const sequentialAdminScenarios = adminScenarios.filter((scenario) => !canCaptureInParallel(scenario))
    const parallelAdminScenarios = adminScenarios.filter(canCaptureInParallel)

    for (const scenario of sequentialAdminScenarios) {
      const result = await navigateAndCapture(coordinator.page, coordinator.audit, scenario, revision)
      metadata.push(result)
      coverage.push(result.sha256
        ? coverageFor(scenario, "captured")
        : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
    }

    const explicitOutputNames = new Set(explicitScreenshotScenarios.map((s) => s.outputName))
    const tasks: CaptureTask[] = [
      ...parallelAdminScenarios.map((scenario): CaptureTask => ({
        label: scenario.id,
        fallbackScenario: scenario,
        run: async (page, audit, batch) => {
          const result = await navigateAndCapture(page, audit, scenario, revision)
          batch.metadata.push(result)
          batch.coverage.push(result.sha256
            ? coverageFor(scenario, "captured")
            : coverageFor(scenario, "skipped", `リダイレクト検出: ${result.finalUrl}`, "リダイレクト先を修正するか、スクリプト側で正しいURLを使用する"))
        },
      })),
      ...resources.map((resource): CaptureTask => ({
        label: `resource:${resource.key}`,
        run: async (page, audit, batch) => {
          if (DEBUG_SCREENSHOTS) console.log(`auto-discover: ${resource.key} (${resource.viewActions.join(", ")})`)
          await captureResource(page, audit, resource, revision, batch.manifests, batch.metadata, batch.coverage, explicitOutputNames)
        },
      })),
    ]

    const poolResult = await runCaptureTasks(browser, revision, tasks)
    for (const batch of poolResult.batches) {
      manifests.push(...batch.manifests)
      metadata.push(...batch.metadata)
      coverage.push(...batch.coverage)
    }
    if (poolResult.errors.length > 0) throw poolResult.errors[0]
  } catch (error: unknown) {
    captureError = error
    const failedScenario = manifests.find(
      (scenario) => scenario.execution === "capture" && !coverage.some((entry) => entry.scenarioId === scenario.id),
    )
    if (failedScenario) {
      coverage.push(coverageFor(
        failedScenario,
        "failed",
        error instanceof Error ? error.message : String(error),
        "失敗原因を修正して同じsource revisionで再実行する",
      ))
    }
  } finally {
    try {
      await writeAuditArtifacts(manifests, metadata, coverage)
    } catch (error: unknown) {
      captureError ??= error
    }
    printCaptureTimingSummary()
    await coordinator.context.close()
    await browser.close()
  }

  if (captureError) throw captureError
}

main().catch((error: unknown) => {
  console.error(error)
  process.exitCode = 1
})
