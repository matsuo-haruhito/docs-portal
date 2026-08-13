import assert from "node:assert/strict"
import test from "node:test"

import ServerRenderedTabsController from "../../app/frontend/controllers/server_rendered_tabs_controller"

class FakeTab {
  tabIndex = 0
  focused = false
  clickCount = 0

  constructor(private readonly selected: boolean) {}

  getAttribute(name: string): string | null {
    return name === "aria-selected" ? String(this.selected) : null
  }

  focus(): void {
    this.focused = true
  }

  click(): void {
    this.clickCount += 1
  }
}

type TestController = ServerRenderedTabsController & { tabTargets: HTMLAnchorElement[] }

function buildController(tabs: FakeTab[]): TestController {
  const controller = Object.create(ServerRenderedTabsController.prototype) as TestController
  Object.defineProperty(controller, "tabTargets", { value: tabs })
  return controller
}

function buildEvent(key: string, currentTarget: FakeTab): KeyboardEvent & { prevented: boolean } {
  let prevented = false
  return {
    key,
    currentTarget,
    preventDefault() {
      prevented = true
    },
    get prevented() {
      return prevented
    },
  } as unknown as KeyboardEvent & { prevented: boolean }
}

test("connect keeps only the selected tab in the tab order", () => {
  const tabs = [new FakeTab(false), new FakeTab(true), new FakeTab(false)]
  const controller = buildController(tabs)

  controller.connect()

  assert.deepEqual(tabs.map((tab) => tab.tabIndex), [-1, 0, -1])
})

test("horizontal arrows move focus with wrap-around without activating links", () => {
  const tabs = [new FakeTab(true), new FakeTab(false), new FakeTab(false)]
  const controller = buildController(tabs)

  const right = buildEvent("ArrowRight", tabs[0])
  controller.keydown(right)
  assert.equal(right.prevented, true)
  assert.deepEqual(tabs.map((tab) => tab.tabIndex), [-1, 0, -1])
  assert.equal(tabs[1].focused, true)
  assert.deepEqual(tabs.map((tab) => tab.clickCount), [0, 0, 0])

  const left = buildEvent("ArrowLeft", tabs[0])
  controller.keydown(left)
  assert.equal(left.prevented, true)
  assert.deepEqual(tabs.map((tab) => tab.tabIndex), [-1, -1, 0])
  assert.equal(tabs[2].focused, true)
})

test("Home and End move focus to the first and last tabs", () => {
  const tabs = [new FakeTab(false), new FakeTab(true), new FakeTab(false)]
  const controller = buildController(tabs)

  controller.keydown(buildEvent("Home", tabs[1]))
  assert.deepEqual(tabs.map((tab) => tab.tabIndex), [0, -1, -1])
  assert.equal(tabs[0].focused, true)

  controller.keydown(buildEvent("End", tabs[0]))
  assert.deepEqual(tabs.map((tab) => tab.tabIndex), [-1, -1, 0])
  assert.equal(tabs[2].focused, true)
})

test("Space activates the focused link while other keys keep native behavior", () => {
  const tabs = [new FakeTab(true), new FakeTab(false)]
  const controller = buildController(tabs)

  const space = buildEvent(" ", tabs[1])
  controller.keydown(space)
  assert.equal(space.prevented, true)
  assert.equal(tabs[1].clickCount, 1)

  const enter = buildEvent("Enter", tabs[1])
  controller.keydown(enter)
  assert.equal(enter.prevented, false)
  assert.equal(tabs[1].clickCount, 1)
})
