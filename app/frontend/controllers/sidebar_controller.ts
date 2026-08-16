import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "docsPortal.sidebar"
const DEFAULT_WIDTH = 360
const MIN_WIDTH = 260
const MAX_WIDTH = 720

interface SidebarState {
  width?: number
  collapsed?: boolean
}

function clampWidth(value: number): number {
  return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, value))
}

function readState(): SidebarState {
  try {
    return JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "{}")
  } catch (_error) {
    return {}
  }
}

function writeState(nextState: Partial<SidebarState>): void {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...readState(), ...nextState }))
}

export default class extends Controller {
  private panel: HTMLElement | null = null
  private toggleButton: HTMLElement | null = null
  private toggleIcon: HTMLElement | null = null
  private resizer: HTMLElement | null = null
  private dragging = false
  private startX = 0
  private startWidth = DEFAULT_WIDTH

  private boundToggle!: () => void
  private boundStartDragging!: (event: PointerEvent) => void
  private boundDrag!: (event: PointerEvent) => void
  private boundStopDragging!: () => void
  private boundResizeByKeyboard!: (event: KeyboardEvent) => void

  connect(): void {
    this.panel = this.element.querySelector("[data-docs-sidebar]")
    this.toggleButton = this.element.querySelector("[data-sidebar-toggle]")
    this.toggleIcon = this.element.querySelector("[data-sidebar-toggle-icon]")
    this.resizer = this.element.querySelector("[data-sidebar-resizer]")
    if (!this.panel || !this.toggleButton || !this.resizer) return

    this.dragging = false
    this.boundToggle = this.toggle.bind(this)
    this.boundStartDragging = this.startDragging.bind(this)
    this.boundDrag = this.drag.bind(this)
    this.boundStopDragging = this.stopDragging.bind(this)
    this.boundResizeByKeyboard = this.resizeByKeyboard.bind(this)

    const storedState = readState()
    const initialWidth = clampWidth(Number(storedState.width) || DEFAULT_WIDTH)
    ;(this.element as HTMLElement).style.setProperty("--sidebar-width", `${initialWidth}px`)
    this.startWidth = initialWidth
    this.applyCollapsedState(storedState.collapsed === true)

    this.toggleButton.addEventListener("click", this.boundToggle)
    this.resizer.addEventListener("pointerdown", this.boundStartDragging as EventListener)
    this.resizer.addEventListener("pointermove", this.boundDrag as EventListener)
    this.resizer.addEventListener("pointerup", this.boundStopDragging)
    this.resizer.addEventListener("pointercancel", this.boundStopDragging)
    this.resizer.addEventListener("keydown", this.boundResizeByKeyboard as EventListener)
  }

  disconnect(): void {
    this.stopDragging()
    this.toggleButton?.removeEventListener("click", this.boundToggle)
    this.resizer?.removeEventListener("pointerdown", this.boundStartDragging as EventListener)
    this.resizer?.removeEventListener("pointermove", this.boundDrag as EventListener)
    this.resizer?.removeEventListener("pointerup", this.boundStopDragging)
    this.resizer?.removeEventListener("pointercancel", this.boundStopDragging)
    this.resizer?.removeEventListener("keydown", this.boundResizeByKeyboard as EventListener)
  }

  private toggle(): void {
    const collapsed = !this.element.classList.contains("is-sidebar-collapsed")
    this.applyCollapsedState(collapsed)
    writeState({ collapsed })
  }

  private startDragging(event: PointerEvent): void {
    if (this.element.classList.contains("is-sidebar-collapsed")) return

    this.dragging = true
    this.startX = event.clientX
    this.startWidth = this.panel!.getBoundingClientRect().width
    document.body.classList.add("is-sidebar-resizing")
    this.panel!.classList.add("is-resizing")
    ;(this.resizer as HTMLElement).setPointerCapture(event.pointerId)
    event.preventDefault()
  }

  private drag(event: PointerEvent): void {
    if (!this.dragging) return

    const nextWidth = clampWidth(this.startWidth + event.clientX - this.startX)
    ;(this.element as HTMLElement).style.setProperty("--sidebar-width", `${nextWidth}px`)
    writeState({ width: nextWidth, collapsed: false })
  }

  private stopDragging(): void {
    if (!this.dragging) return

    this.dragging = false
    document.body.classList.remove("is-sidebar-resizing")
    this.panel?.classList.remove("is-resizing")
  }

  private resizeByKeyboard(event: KeyboardEvent): void {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return

    event.preventDefault()
    const currentWidth = this.panel!.getBoundingClientRect().width
    const step = event.shiftKey ? 40 : 16
    const nextWidth = event.key === "Home" ? MIN_WIDTH :
      event.key === "End" ? MAX_WIDTH :
      event.key === "ArrowLeft" ? currentWidth - step : currentWidth + step
    const width = clampWidth(nextWidth)

    this.element.classList.remove("is-sidebar-collapsed")
    this.applyCollapsedState(false)
    ;(this.element as HTMLElement).style.setProperty("--sidebar-width", `${width}px`)
    writeState({ width, collapsed: false })
  }

  private applyCollapsedState(collapsed: boolean): void {
    this.element.classList.toggle("is-sidebar-collapsed", collapsed)
    this.toggleButton!.setAttribute("aria-expanded", String(!collapsed))
    this.toggleButton!.setAttribute("aria-label", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
    this.toggleButton!.setAttribute("title", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
    this.toggleIcon?.classList.toggle("is-collapsed", collapsed)
  }
}
