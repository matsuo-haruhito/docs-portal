import { Controller } from "@hotwired/stimulus"
import { setupStructuredPreviewTools } from "../lib/structured_preview_tools"

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
    this.clearStructuredPreviews()
  }

  refresh() {
    this.clearStructuredPreviews()
    this.cleanups = setupStructuredPreviewTools()
  }

  clearStructuredPreviews() {
    this.cleanups.forEach((cleanup) => cleanup())
    this.cleanups = []
  }
}
