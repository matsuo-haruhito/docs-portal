import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import test from "node:test"

async function loadControllerClass() {
  const source = readFileSync(resolve("app/frontend/controllers/document_file_browser_controller.js"), "utf8")
  const transformed = source
    .replace('import { Controller } from "@hotwired/stimulus"\n\n', "")
    .replace("export default class extends Controller", "class DocumentFileBrowserController")
    .concat("\nexport { DocumentFileBrowserController }\n")
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(transformed).toString("base64")}`
  const { DocumentFileBrowserController } = await import(moduleUrl)
  return DocumentFileBrowserController
}

function buildItem(search) {
  return { dataset: { itemSearch: search }, hidden: false }
}

function buildSection({ kind = "visible", search = "", items = [] } = {}) {
  return {
    dataset: { sectionKind: kind, sectionSearch: search },
    hidden: false,
    items,
    querySelectorAll(selector) {
      assert.equal(selector, '[data-document-file-browser-target="item"]')
      return this.items
    }
  }
}

function buildButton(kind) {
  return {
    dataset: { documentFileBrowserKindParam: kind },
    attributes: {},
    setAttribute(name, value) {
      this.attributes[name] = value
    }
  }
}

function buildController(ControllerClass, { query = "", sections = [], buttons = [] } = {}) {
  const controller = new ControllerClass()
  controller.queryTarget = { value: query }
  controller.sectionTargets = sections
  controller.filterButtonTargets = buttons
  controller.hasFilterButtonTarget = buttons.length > 0
  controller.statusTarget = { textContent: "" }
  controller.hasStatusTarget = true
  controller.emptyTarget = { hidden: true, textContent: "" }
  controller.hasEmptyTarget = true
  return controller
}

function removeOptionalTargets(controller) {
  controller.hasFilterButtonTarget = false
  controller.filterButtonTargets = []
  controller.hasStatusTarget = false
  delete controller.statusTarget
  controller.hasEmptyTarget = false
  delete controller.emptyTarget
}

function sectionItemVisibility(section) {
  return section.items.map((item) => !item.hidden)
}

test("connect starts with the all kind, shows every item, and updates status and buttons", async () => {
  const ControllerClass = await loadControllerClass()
  const visible = buildSection({ kind: "visible", items: [buildItem("contract"), buildItem("notice")] })
  const debug = buildSection({ kind: "debug", items: [buildItem("trace")] })
  const buttons = ["all", "visible", "debug"].map(buildButton)
  const controller = buildController(ControllerClass, { sections: [visible, debug], buttons })

  controller.connect()

  assert.equal(controller.activeKind, "all")
  assert.deepEqual(sectionItemVisibility(visible), [true, true])
  assert.deepEqual(sectionItemVisibility(debug), [true])
  assert.equal(visible.hidden, false)
  assert.equal(debug.hidden, false)
  assert.equal(controller.statusTarget.textContent, "3件を表示中 / 分類: すべて")
  assert.deepEqual(buttons.map((button) => button.attributes["aria-pressed"]), ["true", "false", "false"])
  assert.equal(controller.emptyTarget.hidden, true)
})

test("kind filtering uses current labels and hides non-matching sections", async () => {
  const ControllerClass = await loadControllerClass()
  const visible = buildSection({ kind: "visible", items: [buildItem("public html")] })
  const grouped = buildSection({ kind: "grouped", items: [buildItem("bundle index"), buildItem("bundle source")] })
  const hidden = buildSection({ kind: "hidden", items: [buildItem("raw source")] })
  const buttons = ["all", "visible", "grouped", "hidden"].map(buildButton)
  const controller = buildController(ControllerClass, { sections: [visible, grouped, hidden], buttons })

  controller.connect()
  controller.selectKind({ params: { kind: "grouped" } })

  assert.deepEqual(sectionItemVisibility(visible), [false])
  assert.deepEqual(sectionItemVisibility(grouped), [true, true])
  assert.deepEqual(sectionItemVisibility(hidden), [false])
  assert.equal(visible.hidden, true)
  assert.equal(grouped.hidden, false)
  assert.equal(hidden.hidden, true)
  assert.equal(controller.statusTarget.textContent, "2件を表示中 / 分類: グループ")
  assert.deepEqual(buttons.map((button) => button.attributes["aria-pressed"]), ["false", "false", "true", "false"])
})

test("section-level search matches every item in that section", async () => {
  const ControllerClass = await loadControllerClass()
  const matchedSection = buildSection({
    kind: "visible",
    search: "Group Alpha attachments",
    items: [buildItem("summary.pdf"), buildItem("details.csv")]
  })
  const unmatchedSection = buildSection({
    kind: "visible",
    search: "Beta attachments",
    items: [buildItem("alpha-only-item.txt")]
  })
  const controller = buildController(ControllerClass, {
    query: " alpha ",
    sections: [matchedSection, unmatchedSection]
  })

  controller.connect()

  assert.deepEqual(sectionItemVisibility(matchedSection), [true, true])
  assert.deepEqual(sectionItemVisibility(unmatchedSection), [true])
  assert.equal(controller.statusTarget.textContent, "3件を表示中 / 検索: alpha")
  assert.equal(controller.emptyTarget.hidden, true)
})

test("item-level search only shows matching items inside otherwise unmatched sections", async () => {
  const ControllerClass = await loadControllerClass()
  const section = buildSection({
    kind: "visible",
    search: "release bundle",
    items: [buildItem("screen capture png"), buildItem("operator note md"), buildItem("source archive zip")]
  })
  const controller = buildController(ControllerClass, { query: "note", sections: [section] })

  controller.connect()

  assert.deepEqual(sectionItemVisibility(section), [false, true, false])
  assert.equal(section.hidden, false)
  assert.equal(controller.statusTarget.textContent, "1件を表示中 / 検索: note")
  assert.equal(controller.emptyTarget.hidden, true)
})

test("empty state explains when only search removes every item", async () => {
  const ControllerClass = await loadControllerClass()
  const section = buildSection({
    kind: "debug",
    search: "debug logs",
    items: [buildItem("trace json")]
  })
  const controller = buildController(ControllerClass, { query: "missing", sections: [section] })

  controller.connect()

  assert.deepEqual(sectionItemVisibility(section), [false])
  assert.equal(section.hidden, true)
  assert.equal(controller.statusTarget.textContent, "0件を表示中 / 検索: missing")
  assert.equal(controller.emptyTarget.hidden, false)
  assert.equal(controller.emptyTarget.textContent, "検索条件に一致するファイルはありません。")
})

test("empty state explains when only a kind filter removes every item", async () => {
  const ControllerClass = await loadControllerClass()
  const visible = buildSection({ kind: "visible", items: [buildItem("public html")] })
  const controller = buildController(ControllerClass, { sections: [visible] })

  controller.connect()
  controller.selectKind({ params: { kind: "debug" } })

  assert.deepEqual(sectionItemVisibility(visible), [false])
  assert.equal(visible.hidden, true)
  assert.equal(controller.statusTarget.textContent, "0件を表示中 / 分類: デバッグ")
  assert.equal(controller.emptyTarget.hidden, false)
  assert.equal(controller.emptyTarget.textContent, "選択した分類に一致するファイルはありません。")
})

test("empty state explains when query and kind filters both apply", async () => {
  const ControllerClass = await loadControllerClass()
  const visible = buildSection({ kind: "visible", items: [buildItem("public html")] })
  const controller = buildController(ControllerClass, { query: "missing", sections: [visible] })

  controller.connect()
  controller.selectKind({ params: { kind: "debug" } })

  assert.deepEqual(sectionItemVisibility(visible), [false])
  assert.equal(visible.hidden, true)
  assert.equal(controller.statusTarget.textContent, "0件を表示中 / 検索: missing / 分類: デバッグ")
  assert.equal(controller.emptyTarget.hidden, false)
  assert.equal(controller.emptyTarget.textContent, "検索条件と分類の両方に一致するファイルはありません。")
})

test("optional filter button, status, and empty targets can be absent", async () => {
  const ControllerClass = await loadControllerClass()
  const section = buildSection({ kind: "other", items: [buildItem("misc source")] })
  const controller = buildController(ControllerClass, { sections: [section] })
  removeOptionalTargets(controller)

  assert.doesNotThrow(() => controller.connect())
  assert.doesNotThrow(() => controller.selectKind({ params: { kind: "other" } }))
  assert.deepEqual(sectionItemVisibility(section), [true])
  assert.equal(section.hidden, false)
})
