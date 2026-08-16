import { Controller } from "@hotwired/stimulus"
import { setupStructuredPreviewTools } from "../lib/structured_preview_tools"

export default class extends Controller {
  private cleanups: Array<() => void> = []
  private boundRefresh!: () => void

  connect(): void {
    this.cleanups = []
    this.boundRefresh = this.refresh.bind(this)
    document.addEventListener("turbo:load", this.boundRefresh)
    document.addEventListener("turbo:render", this.boundRefresh)
    this.refresh()
  }

  disconnect(): void {
    document.removeEventListener("turbo:load", this.boundRefresh)
    document.removeEventListener("turbo:render", this.boundRefresh)
    this.clearStructuredPreviews()
  }

  private refresh(): void {
    this.clearStructuredPreviews()
    this.cleanups = setupStructuredPreviewTools()
  }

  private clearStructuredPreviews(): void {
    this.cleanups.forEach((cleanup) => cleanup())
    this.cleanups = []
  }
}
