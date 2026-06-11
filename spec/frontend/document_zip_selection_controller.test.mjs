import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import test from "node:test"

async function loadControllerClass() {
  const source = readFileSync(resolve("app/frontend/controllers/document_zip_selection_controller.js"), "utf8")
  const transformed = source
    .replace('import { Controller } from "@hotwired/stimulus"\n\n', "")
    .replace("export default class extends Controller", "class DocumentZipSelectionController")
    .concat("\nexport { DocumentZipSelectionController }\n")
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(transformed).toString("base64")}`
  const { DocumentZipSelectionController } = await import(moduleUrl)
  return DocumentZipSelectionController
}

function checkbox({ checked = false, disabled = false } = {}) {
  return { checked, disabled }
}

function buildController(ControllerClass, { scope = "explicit", matchingCount = 42, checkboxes = [] } = {}) {
  const controller = new ControllerClass()
  controller.checkboxTargets = checkboxes
  controller.countTargets = [{ textContent: "" }, { textContent: "" }]
  controller.scopeFieldTarget = { value: scope }
  controller.matchingCountValue = matchingCount
  return controller
}

function countTexts(controller) {
  return controller.countTargets.map((target) => target.textContent)
}

test("connect keeps a matching hidden scope and shows the matching-count copy", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass, {
    scope: "matching",
    matchingCount: 25,
    checkboxes: [checkbox({ checked: true }), checkbox({ checked: true, disabled: true })]
  })

  controller.connect()

  assert.equal(controller.scopeFieldTarget.value, "matching")
  assert.deepEqual(countTexts(controller), [
    "25件選択中（検索結果全体のZIP対象）",
    "25件選択中（検索結果全体のZIP対象）"
  ])
})

test("selectPage selects only enabled checkboxes and uses page count copy", async () => {
  const ControllerClass = await loadControllerClass()
  const enabledA = checkbox()
  const enabledB = checkbox()
  const disabled = checkbox({ disabled: true })
  const controller = buildController(ControllerClass, { checkboxes: [enabledA, disabled, enabledB] })

  controller.selectPage()

  assert.equal(controller.scopeFieldTarget.value, "page")
  assert.equal(enabledA.checked, true)
  assert.equal(enabledB.checked, true)
  assert.equal(disabled.checked, false)
  assert.deepEqual(countTexts(controller), [
    "2件選択中（このページ内のZIP対象）",
    "2件選択中（このページ内のZIP対象）"
  ])
})

test("selectMatching stores matching scope and displays matchingCountValue", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass, {
    matchingCount: 99,
    checkboxes: [checkbox(), checkbox({ disabled: true })]
  })

  controller.selectMatching()

  assert.equal(controller.scopeFieldTarget.value, "matching")
  assert.equal(controller.checkboxTargets[0].checked, true)
  assert.equal(controller.checkboxTargets[1].checked, false)
  assert.deepEqual(countTexts(controller), [
    "99件選択中（検索結果全体のZIP対象）",
    "99件選択中（検索結果全体のZIP対象）"
  ])
})

test("clearSelection returns to explicit scope and clears enabled checkboxes", async () => {
  const ControllerClass = await loadControllerClass()
  const enabled = checkbox({ checked: true })
  const disabled = checkbox({ checked: true, disabled: true })
  const controller = buildController(ControllerClass, {
    scope: "matching",
    checkboxes: [enabled, disabled]
  })

  controller.connect()
  controller.clearSelection()

  assert.equal(controller.scopeFieldTarget.value, "explicit")
  assert.equal(enabled.checked, false)
  assert.equal(disabled.checked, true)
  assert.deepEqual(countTexts(controller), [
    "0件選択中（明示選択）",
    "0件選択中（明示選択）"
  ])
})

test("checkbox changes reset page or matching selection back to explicit scope", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass, {
    scope: "matching",
    matchingCount: 12,
    checkboxes: [checkbox({ checked: true }), checkbox({ checked: true, disabled: true })]
  })

  controller.connect()
  controller.sync({ type: "change" })

  assert.equal(controller.scopeFieldTarget.value, "explicit")
  assert.deepEqual(countTexts(controller), [
    "1件選択中（明示選択）",
    "1件選択中（明示選択）"
  ])
})
