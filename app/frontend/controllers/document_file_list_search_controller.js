import { Controller } from "@hotwired/stimulus"
import { setupDocumentFileListSearch } from "../lib/document_file_list_search"

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
    setupDocumentFileListSearch()
  }
}
