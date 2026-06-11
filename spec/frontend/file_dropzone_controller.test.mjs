import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import test from "node:test"

async function loadControllerClass() {
  const source = readFileSync(resolve("app/frontend/controllers/file_dropzone_controller.js"), "utf8")
  const transformed = source
    .replace('import { Controller } from "@hotwired/stimulus"\n\n', "")
    .replace("export default class extends Controller", "class FileDropzoneController")
    .concat("\nexport { FileDropzoneController }\n")
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(transformed).toString("base64")}`
  const { FileDropzoneController } = await import(moduleUrl)
  return FileDropzoneController
}

class FakeClassList {
  constructor(classes = []) {
    this.classes = new Set(classes)
  }

  add(className) {
    this.classes.add(className)
  }

  remove(className) {
    this.classes.delete(className)
  }

  has(className) {
    return this.classes.has(className)
  }
}

function buildController(ControllerClass, { files = [], hasFilenameTarget = true } = {}) {
  const controller = new ControllerClass()
  controller.draggingClass = "is-dragging"
  controller.element = { classList: new FakeClassList() }
  controller.inputTarget = { files }
  controller.hasFilenameTarget = hasFilenameTarget
  if (hasFilenameTarget) controller.filenameTarget = { textContent: "" }
  return controller
}

function buildEvent({ files = [] } = {}) {
  let prevented = false
  return {
    dataTransfer: { files },
    preventDefault() {
      prevented = true
    },
    get prevented() {
      return prevented
    }
  }
}

test("drag lifecycle prevents default and toggles the dragging class", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass)

  const dragenter = buildEvent()
  controller.dragenter(dragenter)
  assert.equal(dragenter.prevented, true)
  assert.equal(controller.element.classList.has("is-dragging"), true)

  const dragover = buildEvent()
  controller.dragover(dragover)
  assert.equal(dragover.prevented, true)
  assert.equal(controller.element.classList.has("is-dragging"), true)

  const dragleave = buildEvent()
  controller.dragleave(dragleave)
  assert.equal(dragleave.prevented, true)
  assert.equal(controller.element.classList.has("is-dragging"), false)
})

test("drop without files only clears dragging state", async () => {
  const ControllerClass = await loadControllerClass()
  const existingFiles = [{ name: "before.pdf" }]
  const controller = buildController(ControllerClass, { files: existingFiles })
  controller.element.classList.add("is-dragging")
  controller.filenameTarget.textContent = "before.pdf"

  const event = buildEvent({ files: [] })
  controller.drop(event)

  assert.equal(event.prevented, true)
  assert.equal(controller.element.classList.has("is-dragging"), false)
  assert.equal(controller.inputTarget.files, existingFiles)
  assert.equal(controller.filenameTarget.textContent, "before.pdf")
})

test("drop assigns dropped files and displays the first file name", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass)
  controller.element.classList.add("is-dragging")
  const droppedFiles = [{ name: "contract.pdf" }, { name: "appendix.pdf" }]

  controller.drop(buildEvent({ files: droppedFiles }))

  assert.equal(controller.element.classList.has("is-dragging"), false)
  assert.equal(controller.inputTarget.files, droppedFiles)
  assert.equal(controller.filenameTarget.textContent, "contract.pdf")
})

test("change updates the filename and falls back when no file is selected", async () => {
  const ControllerClass = await loadControllerClass()
  const controller = buildController(ControllerClass, { files: [{ name: "notice.txt" }] })

  controller.change()
  assert.equal(controller.filenameTarget.textContent, "notice.txt")

  controller.inputTarget.files = []
  controller.change()
  assert.equal(controller.filenameTarget.textContent, "選択されていません")
})

test("filename updates are no-op when the filename target is absent", async () => {
  const ControllerClass = await loadControllerClass()
  const droppedFiles = [{ name: "hidden.pdf" }]
  const controller = buildController(ControllerClass, { hasFilenameTarget: false })

  assert.doesNotThrow(() => controller.change())
  assert.doesNotThrow(() => controller.drop(buildEvent({ files: droppedFiles })))
  assert.equal(controller.inputTarget.files, droppedFiles)
})
