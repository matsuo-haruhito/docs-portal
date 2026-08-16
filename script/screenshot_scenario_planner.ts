import { type ScreenshotScenario } from "../app/frontend/screenshot_audit"
import { desktopViewport } from "./screenshot_scenarios"
import { type RouteResourceNode } from "./screenshot_route_parser"

export function scenarioFor(
  resource: RouteResourceNode,
  action: "index" | "new" | "show" | "edit",
  url: string,
  urlRule: ScreenshotScenario["urlRule"] = "static",
): ScreenshotScenario {
  const actionNames: Record<string, string> = { index: "一覧", new: "新規作成", show: "詳細", edit: "編集" }
  return {
    id: `${resource.key}.${action}.admin.desktop`,
    screenName: `${resource.name} ${actionNames[action]}`,
    userStory: `管理者が${resource.name}の${actionNames[action]}画面で業務情報を確認する`,
    url,
    urlRule,
    httpMethod: "GET",
    role: "admin",
    viewport: desktopViewport,
    prerequisites: ["管理者でログイン済み", "標準seedデータを投入済み"],
    actions: [],
    stateKind: "default",
    execution: "capture",
    expectedSelectors: ["main"],
    expectedState: {
      description: `${actionNames[action]}画面が表示済み`,
      selector: ".admin-header",
    },
    outputName: `${resource.key}-${action}`,
  }
}
