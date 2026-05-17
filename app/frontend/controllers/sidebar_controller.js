import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "docsPortal.sidebar"
const DEFAULT_WIDTH = 360
const MIN_WIDTH = 260
const MAX_WIDTH = 720

function clampWidth(value) {
  return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, value))
}

function readState() {
  try {
    return JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "{}")
  } catch (_error) {
    return {}
  }
}

function writeState(nextState) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...readState(), ...nextState }))
}

export default class extends Controller {
  connect() {
    this.panel = this.element.querySelector("[data-docs-sidebar]")
    this.toggleButton = this.element.querySelector("[data-sidebar-toggle]")
    this.resizer = this.element.querySelector("[data-sidebar-resizer]")
    if (!this.panel || !this.toggleButton || !this.resizer) return

    this.dragging = false
    this.toggle = this.toggle.bind(this)
    this.startDragging = this.startDragging.bind(this)
    this.drag = this.drag.bind(this)
    this.stopDragging = this.stopDragging.bind(this)
    this.resizeByKeyboard = this.resizeByKeyboard.bind(this)

    const storedState = readState()
    const initialWidth = clampWidth(Number(storedState.width) || DEFAULT_WIDTH)
    this.element.style.setProperty("--sidebar-width", `${initialWidth}px`)
    this.startWidth = initialWidth
    this.applyCollapsedState(storedState.collapsed === true)

    this.toggleButton.addEventListener("click", this.toggle)
    this.resizer.addEventListener("pointerdown", this.startDragging)
    this.resizer.addEventListener("pointermove", this.drag)
    this.resizer.addEventListener("pointerup", this.stopDragging)
    this.resizer.addEventListener("pointercancel", this.stopDragging)
    this.resizer.addEventListener("keydown", this.resizeByKeyboard)
  }

  disconnect() {
    this.stopDragging()
    this.toggleButton?.removeEventListener("click", this.toggle)
    this.resizer?.removeEventListener("pointerdown", this.startDragging)
    this.resizer?.removeEventListener("pointermove", this.drag)
    this.resizer?.removeEventListener("pointerup", this.stopDragging)
    this.resizer?.removeEventListener("pointercancel", this.stopDragging)
    this.resizer?.removeEventListener("keydown", this.resizeByKeyboard)
  }

  toggle() {
    const collapsed = !this.element.classList.contains("is-sidebar-collapsed")
    this.applyCollapsedState(collapsed)
    writeState({ collapsed })
  }

  startDragging(event) {
    if (this.element.classList.contains("is-sidebar-collapsed")) return

    this.dragging = true
    this.startX = event.clientX
    this.startWidth = this.panel.getBoundingClientRect().width
    document.body.classList.add("is-sidebar-resizing")
    this.panel.classList.add("is-resizing")
    this.resizer.setPointerCapture(event.pointerId)
    event.preventDefault()
  }

  drag(event) {
    if (!this.dragging) return

    const nextWidth = clampWidth(this.startWidth + event.clientX - this.startX)
    this.element.style.setProperty("--sidebar-width", `${nextWidth}px`)
    writeState({ width: nextWidth, collapsed: false })
  }

  stopDragging() {
    if (!this.dragging) return

    this.dragging = false
    document.body.classList.remove("is-sidebar-resizing")
    this.panel?.classList.remove("is-resizing")
  }

  resizeByKeyboard(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return

    event.preventDefault()
    const currentWidth = this.panel.getBoundingClientRect().width
    const step = event.shiftKey ? 40 : 16
    const nextWidth = event.key === "Home" ? MIN_WIDTH :
      event.key === "End" ? MAX_WIDTH :
      event.key === "ArrowLeft" ? currentWidth - step : currentWidth + step
    const width = clampWidth(nextWidth)

    this.element.classList.remove("is-sidebar-collapsed")
    this.applyCollapsedState(false)
    this.element.style.setProperty("--sidebar-width", `${width}px`)
    writeState({ width, collapsed: false })
  }

  applyCollapsedState(collapsed) {
    this.element.classList.toggle("is-sidebar-collapsed", collapsed)
    this.toggleButton.setAttribute("aria-expanded", String(!collapsed))
    this.toggleButton.setAttribute("aria-label", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
    this.toggleButton.setAttribute("title", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
    this.toggleButton.textContent = collapsed ? "▶" : "◀"
  }
}
