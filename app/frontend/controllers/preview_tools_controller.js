import { Controller } from "@hotwired/stimulus"
import { setupMarkdownPreviewTableTools } from "../lib/markdown_preview_table_tools"
import { setupDocumentFileListSearch } from "../lib/document_file_list_search"
import { setupStructuredPreviewTools } from "../lib/structured_preview_tools"
import { setupArchivePreviewTools } from "../lib/archive_preview_tools"
import { setupSiteViewerIframeHeightSync } from "../lib/site_viewer_iframe_height"

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
    setupMarkdownPreviewTableTools()
    setupDocumentFileListSearch()
    setupStructuredPreviewTools()
    setupArchivePreviewTools()
  }
}
