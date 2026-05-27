import { Controller } from "@hotwired/stimulus"
import { setupMarkdownPreviewTableTools } from "../lib/markdown_preview_table_tools"
import { setupMarkdownPreviewCodeblockTools } from "../lib/markdown_preview_codeblock_tools"
import { setupMarkdownPreviewDocumentSearch } from "../lib/markdown_preview_document_search"
import { setupDocumentFileListSearch } from "../lib/document_file_list_search"
import { setupCsvPreviewTableTools } from "../lib/csv_preview_table_tools"
import { setupStructuredPreviewTools } from "../lib/structured_preview_tools"
import { setupArchivePreviewTools } from "../lib/archive_preview_tools"
import { setupImagePreviewTools } from "../lib/image_preview_tools"
import { setupPdfPreviewTools } from "../lib/pdf_preview_tools"
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
    setupMarkdownPreviewDocumentSearch()
    setupMarkdownPreviewTableTools()
    setupMarkdownPreviewCodeblockTools()
    setupDocumentFileListSearch()
    setupCsvPreviewTableTools()
    setupStructuredPreviewTools()
    setupArchivePreviewTools()
    setupImagePreviewTools()
    setupPdfPreviewTools()
  }
}
