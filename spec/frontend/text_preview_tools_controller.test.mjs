import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import test from "node:test"

async function loadControllerClass() {
  const source = readFileSync(resolve("app/frontend/controllers/text_preview_tools_controller.js"), "utf8")
  const transformed = source
    .replace('import { Controller } from "@hotwired/stimulus"\n\n', "")
    .replace("export default class extends Controller", "class TextPreviewToolsController")
    .concat("\nexport { TextPreviewToolsController }\n")
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(transformed).toString("base64")}`
  const { TextPreviewToolsController } = await import(moduleUrl)
  return TextPreviewToolsController
}

function buildLineRow(id) {
  return {
    id,
    attributes: {},
    classList: {
      values: new Set(),
      toggle(name, active) {
        if (active) {
          this.values.add(name)
        } else {
          this.values.delete(name)
        }
      },
      contains(name) {
        return this.values.has(name)
      }
    },
    setAttribute(name, value) {
      this.attributes[name] = value
    },
    removeAttribute(name) {
      delete this.attributes[name]
    }
  }
}

function buildController(ControllerClass, rows) {
  const controller = new ControllerClass()
  controller.element = {
    querySelectorAll(selector) {
      assert.equal(selector, "[data-text-preview-line]")
      return rows
    }
  }
  return controller
}

function setLocationHash(hash) {
  global.window = {
    location: { hash },
    addEventListener() {},
    removeEventListener() {}
  }
}

test("syncAnchorTarget marks only the deep-link target row as aria-current", async () => {
  setLocationHash("#L2")
  const ControllerClass = await loadControllerClass()
  const rows = [buildLineRow("L1"), buildLineRow("L2"), buildLineRow("L3")]
  const controller = buildController(ControllerClass, rows)

  controller.syncAnchorTarget()

  assert.equal(rows[0].classList.contains("is-text-preview-anchor-target"), false)
  assert.equal(rows[0].attributes["aria-current"], undefined)
  assert.equal(rows[1].classList.contains("is-text-preview-anchor-target"), true)
  assert.equal(rows[1].attributes["aria-current"], "location")
  assert.equal(rows[2].classList.contains("is-text-preview-anchor-target"), false)
  assert.equal(rows[2].attributes["aria-current"], undefined)
})

test("syncAnchorTarget clears the target cue when the hash is not a line anchor", async () => {
  setLocationHash("#section")
  const ControllerClass = await loadControllerClass()
  const target = buildLineRow("L2")
  target.classList.toggle("is-text-preview-anchor-target", true)
  target.setAttribute("aria-current", "location")
  const rows = [buildLineRow("L1"), target]
  const controller = buildController(ControllerClass, rows)

  controller.syncAnchorTarget()

  assert.equal(target.classList.contains("is-text-preview-anchor-target"), false)
  assert.equal(target.attributes["aria-current"], undefined)
})

test("view wires text preview rows to the controller without adding visible row labels", () => {
  const view = readFileSync(resolve("app/views/document_files/show_text_preview.html.slim"), "utf8")

  assert.match(view, /data-controller="text-preview-tools"/)
  assert.match(view, /data-text-preview-tools="true"/)
  assert.match(view, /li\.line-preview__row id=line_anchor data-text-preview-line="true" data-text-preview-line-number=line_number/)
  assert.match(view, /aria: \{ label: "#\{line_number\}行目へのリンク" \}/)
  assert.doesNotMatch(view, /aria-current="location"/)
})

test("entrypoint registers target and match cue assets separately", () => {
  const entrypoint = readFileSync(resolve("app/frontend/entrypoints/application.js"), "utf8")
  const styles = readFileSync(resolve("app/frontend/entrypoints/text_preview_cues.css"), "utf8")

  assert.match(entrypoint, /import "\.\/text_preview_cues\.css"/)
  assert.match(entrypoint, /import TextPreviewToolsController from "\.\.\/controllers\/text_preview_tools_controller"/)
  assert.match(entrypoint, /application\.register\("text-preview-tools", TextPreviewToolsController\)/)
  assert.match(styles, /\.line-preview__row\.is-text-preview-anchor-target/)
  assert.match(styles, /\.line-preview__row\.is-text-preview-match \.line-preview__code/)
  assert.match(styles, /\.line-preview__row\.is-text-preview-anchor-target\.is-text-preview-match \.line-preview__code/)
})
