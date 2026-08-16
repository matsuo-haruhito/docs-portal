import { Controller } from "@hotwired/stimulus"

export default class DirtyFormController extends Controller {
  static values = { message: { type: String, default: "変更が保存されていません。ページを離れますか？" } }

  declare messageValue: string

  private dirty = false
  private submitted = false
  private onInput!: (event: Event) => void
  private onSubmit!: () => void
  private onSubmitEnd!: (event: Event) => void
  private onKeydown!: (event: KeyboardEvent) => void
  private onBeforeUnload!: (event: BeforeUnloadEvent) => void
  private onBeforeVisit!: (event: Event) => void
  private indicator: HTMLSpanElement | null = null
  private savedTimer: number | undefined

  connect(): void {
    this.dirty = false
    this.submitted = false
    this.onInput = (event: Event) => this.markDirty(event)
    this.onSubmit = () => this.markSubmitting()
    this.onSubmitEnd = (event: Event) => this.handleSubmitEnd(event)
    this.onKeydown = (event: KeyboardEvent) => this.handleKeydown(event)
    this.onBeforeUnload = (event: BeforeUnloadEvent) => this.handleBeforeUnload(event)
    this.onBeforeVisit = (event: Event) => this.handleBeforeVisit(event)
    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("change", this.onInput)
    this.element.addEventListener("submit", this.onSubmit)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    document.addEventListener("keydown", this.onKeydown as EventListener)
    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    this.createIndicator()
  }

  disconnect(): void {
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("change", this.onInput)
    this.element.removeEventListener("submit", this.onSubmit)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    document.removeEventListener("keydown", this.onKeydown as EventListener)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    window.clearTimeout(this.savedTimer)
    this.element.removeAttribute("aria-busy")
    this.indicator?.remove()
  }

  private markDirty(event: Event): void {
    if (this.submitted) return
    this.dirty = true
    const target = event.target as HTMLInputElement | null
    if (target?.matches?.("input, select, textarea") && target.type !== "checkbox" && target.type !== "radio") {
      target.classList.add("is-dirty-field")
    }
    this.setState("未保存", "warning")
  }

  private markSubmitting(): void {
    this.submitted = true
    this.element.setAttribute("aria-busy", "true")
    this.setState("保存中…", "primary")
    this.toggleSubmitButtons(true)
  }

  private handleSubmitEnd(event: Event): void {
    this.submitted = false
    this.element.removeAttribute("aria-busy")
    this.toggleSubmitButtons(false)

    const detail = (event as CustomEvent).detail
    if (detail.success) {
      this.dirty = false
      this.element.querySelectorAll(".is-dirty-field").forEach((field) => field.classList.remove("is-dirty-field"))
      this.setState("保存済み", "success")
      window.clearTimeout(this.savedTimer)
      this.savedTimer = window.setTimeout(() => this.setState("保存済み", "secondary"), 1600)
    } else {
      this.dirty = true
      this.setState("保存失敗", "danger")
    }
  }

  private handleKeydown(event: KeyboardEvent): void {
    if (!(event.ctrlKey || event.metaKey) || event.key.toLowerCase() !== "s") return
    if (event.repeat || event.isComposing || this.submitted) return
    if (!this.element.isConnected || !this.shouldHandleShortcut(event)) return

    const submitter = this.primarySubmitter()
    if (!submitter) return

    event.preventDefault()
    ;(this.element as HTMLFormElement).requestSubmit(submitter)
  }

  private primarySubmitter(): HTMLButtonElement | HTMLInputElement | null {
    return this.element.querySelector([
      "[data-dirty-form-primary-submit]:not(:disabled)",
      "button[type='submit']:not([formaction]):not(:disabled)",
      "input[type='submit']:not([formaction]):not(:disabled)"
    ].join(", "))
  }

  private shouldHandleShortcut(event: KeyboardEvent): boolean {
    if (this.element.contains(event.target as Node) || this.element.contains(document.activeElement)) return true
    return document.querySelectorAll("form[data-controller~='dirty-form']").length === 1
  }

  private handleBeforeUnload(event: BeforeUnloadEvent): void {
    if (!this.dirty || this.submitted) return
    event.preventDefault()
    event.returnValue = this.messageValue
  }

  private handleBeforeVisit(event: Event): void {
    if (!this.dirty || this.submitted || (event as Event & { dirtyFormHandled?: boolean }).dirtyFormHandled) return
    ;(event as Event & { dirtyFormHandled?: boolean }).dirtyFormHandled = true
    if (!confirm(this.messageValue)) event.preventDefault()
  }

  private toggleSubmitButtons(disabled: boolean): void {
    this.element.querySelectorAll<HTMLButtonElement | HTMLInputElement>("button[type='submit'], input[type='submit']").forEach((button) => { button.disabled = disabled })
  }

  private createIndicator(): void {
    this.element.querySelector(":scope > .form-save-state")?.remove()
    this.indicator = document.createElement("span")
    this.indicator.className = "form-save-state badge text-bg-secondary"
    this.indicator.textContent = "保存済み"
    this.element.appendChild(this.indicator)
  }

  private setState(text: string, tone: string): void {
    if (!this.indicator) return
    this.indicator.textContent = text
    this.indicator.className = `form-save-state badge text-bg-${tone}`
  }
}
