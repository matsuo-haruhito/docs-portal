export type ScreenshotRole = "guest" | "admin" | "company_master_admin" | "external"
export type ScreenshotHttpMethod = "GET" | "POST" | "PATCH" | "DELETE"
export type ScreenshotStateKind = "default" | "mobile" | "restricted" | "empty" | "error" | "processing"
export type ScreenshotExecution = "capture" | "deferred"
export type ScreenshotDocumentRole = "primary" | "supplemental" | "exclude"

export interface ScreenshotViewport {
  width: number
  height: number
  name: string
}

export interface ScreenshotExpectedState {
  description: string
  selector: string
}

export interface ScreenshotAction {
  type: "fill" | "click"
  selector: string
  value?: string
  description: string
}

export interface ScreenshotDeferral {
  reason: string
  resumeCondition: string
}

export interface ScreenshotScenario {
  id: string
  screenName: string
  userStory: string
  url: string
  urlRule: "static" | "first-record" | "nested-first-record" | "dynamic"
  httpMethod: ScreenshotHttpMethod
  role: ScreenshotRole
  viewport: ScreenshotViewport
  prerequisites: string[]
  actions: ScreenshotAction[]
  stateKind: ScreenshotStateKind
  execution: ScreenshotExecution
  deferral?: ScreenshotDeferral
  expectedSelectors: string[]
  expectedState: ScreenshotExpectedState
  outputName: string
  /** 業務レベルの期待動作。screen_guide の操作説明に使う */
  expectedBehavior?: string[]
  /** ドキュメント上の役割。省略時は stateKind から推論（default→primary, それ以外→supplemental） */
  documentRole?: ScreenshotDocumentRole
}

export interface SecretFinding {
  pattern: string
  sample: string
}

export interface ImageDigest {
  outputName: string
  sha256: string
}

export interface DuplicateImageGroup {
  sha256: string
  outputNames: string[]
}

const IDENTIFIER_PATTERN = /^[a-z0-9]+(?:[._-][a-z0-9]+)*$/
const OUTPUT_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

const SECRET_PATTERNS: ReadonlyArray<{ name: string; expression: RegExp }> = [
  { name: "private-key", expression: /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g },
  { name: "aws-access-key", expression: /\bAKIA[0-9A-Z]{16}\b/g },
  {
    name: "credential-assignment",
    expression: /\b(?:api[_-]?key|client[_-]?secret|access[_-]?token)\b\s*[:=]\s*["']?[^\s"'&<>]{8,}/gi,
  },
]

export function validateScenarioManifest(scenarios: readonly ScreenshotScenario[]): string[] {
  const errors: string[] = []
  const ids = new Set<string>()
  const outputs = new Set<string>()

  for (const scenario of scenarios) {
    if (!IDENTIFIER_PATTERN.test(scenario.id)) errors.push(`invalid scenario id: ${scenario.id}`)
    if (ids.has(scenario.id)) errors.push(`duplicate scenario id: ${scenario.id}`)
    ids.add(scenario.id)

    if (!scenario.screenName.trim()) errors.push(`screen name is required: ${scenario.id}`)
    if (!scenario.userStory.trim()) errors.push(`user story is required: ${scenario.id}`)
    if (!scenario.url.startsWith("/")) errors.push(`url must be an absolute path: ${scenario.id}`)
    if (scenario.prerequisites.length === 0 || scenario.prerequisites.some((value) => !value.trim())) {
      errors.push(`prerequisite is required: ${scenario.id}`)
    }
    if (scenario.actions.some((action) => !action.selector.trim() || !action.description.trim())) {
      errors.push(`action details are required: ${scenario.id}`)
    }
    if (scenario.execution === "deferred") {
      if (!scenario.deferral?.reason.trim() || !scenario.deferral.resumeCondition.trim()) {
        errors.push(`deferred reason and resume condition are required: ${scenario.id}`)
      }
    } else if (scenario.deferral) {
      errors.push(`captured scenario cannot have deferral: ${scenario.id}`)
    }
    if (scenario.expectedSelectors.length === 0) errors.push(`expected selector is required: ${scenario.id}`)
    if (!scenario.expectedState.description.trim() || !scenario.expectedState.selector.trim()) {
      errors.push(`expected state is required: ${scenario.id}`)
    }
    if (scenario.viewport.width <= 0 || scenario.viewport.height <= 0) {
      errors.push(`viewport must be positive: ${scenario.id}`)
    }
    if (!OUTPUT_PATTERN.test(scenario.outputName)) errors.push(`invalid output name: ${scenario.outputName}`)
    if (outputs.has(scenario.outputName)) errors.push(`duplicate output name: ${scenario.outputName}`)
    outputs.add(scenario.outputName)
  }

  return errors
}

export function detectSecretPatterns(value: string): SecretFinding[] {
  const findings: SecretFinding[] = []

  for (const { name, expression } of SECRET_PATTERNS) {
    expression.lastIndex = 0
    for (const match of value.matchAll(expression)) {
      findings.push({ pattern: name, sample: redactSecretSample(match[0]) })
    }
  }

  return findings
}

export function groupDuplicateImageHashes(digests: readonly ImageDigest[]): DuplicateImageGroup[] {
  const grouped = new Map<string, string[]>()

  for (const digest of digests) {
    const outputNames = grouped.get(digest.sha256) ?? []
    outputNames.push(digest.outputName)
    grouped.set(digest.sha256, outputNames)
  }

  return [...grouped.entries()]
    .filter(([, outputNames]) => outputNames.length > 1)
    .map(([sha256, outputNames]) => ({ sha256, outputNames: [...outputNames].sort() }))
    .sort((left, right) => left.sha256.localeCompare(right.sha256))
}

export function isExpectedUrl(actualUrl: string, baseUrl: string, expectedPath: string): boolean {
  const actual = new URL(actualUrl)
  const expected = new URL(expectedPath, baseUrl)
  return actual.origin === expected.origin && actual.pathname === expected.pathname && actual.search === expected.search
}

function redactSecretSample(value: string): string {
  if (value.length <= 8) return "[REDACTED]"
  return `${value.slice(0, 4)}…[REDACTED]`
}
