import { Controller } from "@hotwired/stimulus"
import { setupImagePreviewTools } from "../lib/image_preview_tools"

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
    this.clearImagePreviews()
  }

  private refresh(): void {
    this.clearImagePreviews()
    this.cleanups = setupImagePreviewTools()
  }

  private clearImagePreviews(): void {
    this.cleanups.forEach((cleanup) => cleanup?.())
    this.cleanups = []
  }
}
