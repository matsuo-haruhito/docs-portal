import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import test from "node:test"

async function loadControllerClass() {
  const source = readFileSync(resolve("app/frontend/controllers/nav_dropdowns_controller.js"), "utf8")
  const transformed = source
    .replace('import { Controller } from "@hotwired/stimulus"\n\n', "")
    .replace("export default class extends Controller", "class NavDropdownsController")
    .concat("\nexport { NavDropdownsController }\n")
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(transformed).toString("base64")}`
  const { NavDropdownsController } = await import(moduleUrl)
  return NavDropdownsController
}

class FakeElement {
  constructor({ tagName = "DIV", className = "", dataset = {}, open = false } = {}) {
    this.tagName = tagName
    this.className = className
    this.dataset = dataset
    this.open = open
    this.children = []
    this.parentElement = null
    this.focused = false
  }

  appendChild(child) {
    child.parentElement = this
    this.children.push(child)
    return child
  }

  closest(selector) {
    let current = this
    while (current) {
      if (matchesSelector(current, selector)) return current
      current = current.parentElement
    }
    return null
  }

  querySelector(selector) {
    return collectDescendants(this).find((node) => matchesSelector(node, selector)) || null
  }

  querySelectorAll(selector) {
    return collectDescendants(this).filter((node) => matchesSelector(node, selector))
  }

  focus() {
    this.focused = true
  }
}

function collectDescendants(root) {
  return root.children.flatMap((child) => [child, ...collectDescendants(child)])
}

function matchesSelector(node, selector) {
  if (selector === "[data-nav-dropdown]") return node.dataset.navDropdown === "true"
  if (selector === "[data-nav-dropdown][open]") return node.dataset.navDropdown === "true" && node.open
  if (selector === "summary.nav-dropdown__summary") {
    return node.tagName === "SUMMARY" && node.className.split(/\s+/).includes("nav-dropdown__summary")
  }
  return false
}

function buildDropdown({ open = false } = {}) {
  const dropdown = new FakeElement({ tagName: "DETAILS", dataset: { navDropdown: "true" }, open })
  const summary = dropdown.appendChild(new FakeElement({ tagName: "SUMMARY", className: "nav-dropdown__summary" }))
  dropdown.summary = summary
  dropdown.appendChild(new FakeElement({ tagName: "A" }))
  return dropdown
}

function buildController(ControllerClass) {
  const controller = new ControllerClass()
  controller.element = new FakeElement()
  return controller
}

test("opening one nav dropdown closes the other open dropdowns", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass)
  const first = controller.element.appendChild(buildDropdown({ open: true }))
  const second = controller.element.appendChild(buildDropdown({ open: true }))

  controller.onToggle({ target: second })

  assert.equal(first.open, false)
  assert.equal(second.open, true)
})

test("outside clicks close open nav dropdowns without changing inside clicks", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass)
  const first = controller.element.appendChild(buildDropdown({ open: true }))
  const second = controller.element.appendChild(buildDropdown({ open: true }))

  controller.onClick({ target: first.summary })
  assert.equal(first.open, true)
  assert.equal(second.open, true)

  controller.onClick({ target: new FakeElement() })
  assert.equal(first.open, false)
  assert.equal(second.open, false)
})

test("Escape closes open nav dropdowns and restores focus to the summary", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass)
  const first = controller.element.appendChild(buildDropdown({ open: true }))
  const second = controller.element.appendChild(buildDropdown({ open: true }))

  controller.onKeydown({ key: "Escape", target: second.summary })

  assert.equal(first.open, false)
  assert.equal(second.open, false)
  assert.equal(second.summary.focused, true)
  assert.equal(first.summary.focused, false)
})

test("Escape restores focus to the first open dropdown when the event starts outside a dropdown", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass)
  const first = controller.element.appendChild(buildDropdown({ open: true }))
  const second = controller.element.appendChild(buildDropdown({ open: true }))

  controller.onKeydown({ key: "Escape", target: new FakeElement() })

  assert.equal(first.open, false)
  assert.equal(second.open, false)
  assert.equal(first.summary.focused, true)
  assert.equal(second.summary.focused, false)
})
