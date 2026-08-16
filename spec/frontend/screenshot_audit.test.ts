import path from "node:path"
import { describe, expect, it } from "vitest"
import {
  discoverResourcesFromRoutes,
  parseResourceLine,
  singularResourceGetPaths,
} from "../../script/screenshot_route_parser"
import { scenarioFor } from "../../script/screenshot_scenario_planner"
import {
  detectSecretPatterns,
  groupDuplicateImageHashes,
  isExpectedUrl,
  validateScenarioManifest,
  type ScreenshotScenario,
} from "../../app/frontend/screenshot_audit"

const validScenario: ScreenshotScenario = {
  id: "admin-documents.index.admin.desktop",
  screenName: "文書マスタ一覧",
  userStory: "管理者が文書マスタを検索して対象文書を確認する",
  url: "/admin/documents",
  urlRule: "static",
  httpMethod: "GET",
  role: "admin",
  viewport: { name: "desktop", width: 1440, height: 900 },
  prerequisites: ["管理者でログイン済み"],
  actions: [],
  stateKind: "default",
  execution: "capture",
  expectedSelectors: ["main table"],
  expectedState: { description: "文書一覧が表示済み", selector: ".admin-header" },
  outputName: "admin-documents-index",
}

describe("validateScenarioManifest", () => {
  it("accepts a complete unique manifest", () => {
    expect(validateScenarioManifest([validScenario])).toEqual([])
  })

  it("accepts a deferred scenario only when reason and resume condition are recorded", () => {
    expect(validateScenarioManifest([{
      ...validScenario,
      id: "admin-documents.empty.admin.desktop",
      stateKind: "empty",
      execution: "deferred",
      deferral: { reason: "空fixtureがない", resumeCondition: "fixtureを追加する" },
      outputName: "admin-documents-empty",
    }])).toEqual([])
  })

  it("rejects duplicate identifiers, outputs, and incomplete expectations", () => {
    const invalid = {
      ...validScenario,
      id: "Invalid ID",
      userStory: "",
      prerequisites: [],
      expectedSelectors: [],
      expectedState: { description: "", selector: "" },
      outputName: "Invalid output.png",
    }
    expect(validateScenarioManifest([invalid, invalid])).toEqual(expect.arrayContaining([
      "invalid scenario id: Invalid ID",
      "duplicate scenario id: Invalid ID",
      "user story is required: Invalid ID",
      "prerequisite is required: Invalid ID",
      "expected selector is required: Invalid ID",
      "invalid output name: Invalid output.png",
      "duplicate output name: Invalid output.png",
    ]))
  })

  it("rejects a deferred scenario without traceable restart information", () => {
    const invalid = {
      ...validScenario,
      execution: "deferred" as const,
      deferral: { reason: "", resumeCondition: "" },
    }
    expect(validateScenarioManifest([invalid])).toContain(
      "deferred reason and resume condition are required: admin-documents.index.admin.desktop",
    )
  })
})

describe("detectSecretPatterns", () => {
  it("rejects known credentials without returning the full value", () => {
    const findings = detectSecretPatterns("api_key=super-secret-value and AKIAABCDEFGHIJKLMNOP")
    expect(findings.map((finding) => finding.pattern)).toEqual(["aws-access-key", "credential-assignment"])
    expect(findings.every((finding) => !finding.sample.includes("super-secret-value"))).toBe(true)
  })

  it("does not flag ordinary password labels", () => {
    expect(detectSecretPatterns("パスワードを入力してください password field")).toEqual([])
    expect(detectSecretPatterns("password123!")).toEqual([])
  })
})

describe("groupDuplicateImageHashes", () => {
  it("reports only duplicate hashes in stable order", () => {
    expect(groupDuplicateImageHashes([
      { outputName: "second", sha256: "bbb" },
      { outputName: "first-b", sha256: "aaa" },
      { outputName: "unique", sha256: "ccc" },
      { outputName: "first-a", sha256: "aaa" },
      { outputName: "third", sha256: "bbb" },
    ])).toEqual([
      { sha256: "aaa", outputNames: ["first-a", "first-b"] },
      { sha256: "bbb", outputNames: ["second", "third"] },
    ])
  })
})

describe("isExpectedUrl", () => {
  it("accepts only the same origin, path, and query", () => {
    expect(isExpectedUrl("http://app:3000/admin/documents?status=draft#top", "http://app:3000", "/admin/documents?status=draft")).toBe(true)
    expect(isExpectedUrl("http://app:3000/session/new", "http://app:3000", "/admin/documents")).toBe(false)
    expect(isExpectedUrl("https://example.test/admin/documents", "http://app:3000", "/admin/documents")).toBe(false)
  })
})

describe("screenshot route parser", () => {
  it("parses plural and singular defaults and respects only/except", () => {
    expect(parseResourceLine("resources :orders")).toMatchObject({
      name: "orders",
      singular: false,
      actions: ["index", "new", "create", "show", "edit", "update", "destroy"],
    })
    expect(parseResourceLine("resources :orders, except: [ :show, :destroy ]")).toMatchObject({
      singular: false,
      actions: ["index", "new", "create", "edit", "update"],
    })
    expect(parseResourceLine("resource :profile")).toMatchObject({
      name: "profile",
      singular: true,
      actions: ["show", "new", "edit"],
    })
    expect(parseResourceLine("resource :profile, only: [ :show ]")).toMatchObject({
      singular: true,
      actions: ["show"],
    })
    expect(parseResourceLine("resource :profile, except: %i[new edit]")).toMatchObject({
      singular: true,
      actions: ["show"],
    })
  })

  it("discovers admin namespace resources from the actual routes file", async () => {
    const resources = await discoverResourcesFromRoutes(path.resolve("config/routes.rb"))

    const adminDocuments = resources.find((r) => r.key === "admin-documents")
    expect(adminDocuments).toBeDefined()
    expect(adminDocuments!.basePath).toBe("/admin/documents")
    expect(adminDocuments!.namespacePrefix).toContain("admin")

    const adminProjects = resources.find((r) => r.key === "admin-projects")
    expect(adminProjects).toBeDefined()
    expect(adminProjects!.basePath).toBe("/admin/projects")
  })

  it("plans scenarios for singular resources", () => {
    const resource = {
      key: "admin-api-specification",
      name: "api_specification",
      basePath: "/admin/api_specification",
      actions: ["show"],
      parentKey: null,
      namespacePrefix: ["admin"],
      singular: true,
    }
    const paths = singularResourceGetPaths(resource)
    expect(paths).toEqual([{ action: "show", path: "/admin/api_specification" }])
    expect(scenarioFor(resource, "show", "/admin/api_specification")).toMatchObject({
      id: "admin-api-specification.show.admin.desktop",
      url: "/admin/api_specification",
      outputName: "admin-api-specification-show",
    })
  })
})
