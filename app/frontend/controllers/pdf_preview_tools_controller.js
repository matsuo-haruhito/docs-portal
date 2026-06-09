import { Controller } from "@hotwired/stimulus"
import { setupPdfPreviewTools } from "../lib/pdf_preview_tools"

export default class extends Controller {
  connect() {
    this.cleanups = []
    this.refresh = this.refresh.bind(this)
    document.addEventListener("turbo:load", this.refresh)
    document.addEventListener("turbo:render", this.refresh)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.refresh)
    document.removeEventListener("turbo:render", this.refresh)
    this.clearPdfPreviews()
  }

  refresh() {
    this.clearPdfPreviews()
    this.cleanups = setupPdfPreviewTools()
  }

  clearPdfPreviews() {
    this.cleanups.forEach((cleanup) => cleanup())
    this.cleanups = []
  }
}
