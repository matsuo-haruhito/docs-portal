import { Controller } from "@hotwired/stimulus"
import { setupPdfPreviewTools } from "../lib/pdf_preview_tools"

export default class extends Controller {
  private cleanups: Array<(() => void) | null> = []
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
    this.clearPdfPreviews()
  }

  private refresh(): void {
    this.clearPdfPreviews()
    this.cleanups = setupPdfPreviewTools()
  }

  private clearPdfPreviews(): void {
    this.cleanups.forEach((cleanup) => cleanup?.())
    this.cleanups = []
  }
}
