import { Controller } from "@hotwired/stimulus"
import { setupSiteViewerIframeHeightSync } from "../lib/site_viewer_iframe_height"
import { setupSiteViewerHeadingOutline } from "../lib/site_viewer_heading_outline"

export default class extends Controller {
  connect() {
    this.refresh = this.refresh.bind(this)
    document.addEventListener("turbo:load", this.refresh)
    document.addEventListener("turbo:render", this.refresh)
    this.refresh()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.refresh)
    document.removeEventListener("turbo:render", this.refresh)
  }

  refresh() {
    setupSiteViewerIframeHeightSync()
    setupSiteViewerHeadingOutline()
  }
}
