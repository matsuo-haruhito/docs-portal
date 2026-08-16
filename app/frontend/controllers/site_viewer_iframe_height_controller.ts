import { Controller } from "@hotwired/stimulus"
import { setupSiteViewerIframeHeightSync } from "../lib/site_viewer_iframe_height"
import { setupSiteViewerHeadingOutline } from "../lib/site_viewer_heading_outline"

export default class extends Controller {
  private boundRefresh!: () => void

  connect(): void {
    this.boundRefresh = this.refresh.bind(this)
    document.addEventListener("turbo:load", this.boundRefresh)
    document.addEventListener("turbo:render", this.boundRefresh)
    this.refresh()
  }

  disconnect(): void {
    document.removeEventListener("turbo:load", this.boundRefresh)
    document.removeEventListener("turbo:render", this.boundRefresh)
  }

  private refresh(): void {
    setupSiteViewerIframeHeightSync()
    setupSiteViewerHeadingOutline()
  }
}
