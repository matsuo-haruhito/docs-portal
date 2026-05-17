import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    document.addEventListener("click", this.onClick, true)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick, true)
  }

  onClick(event) {
    if (event.target.closest(".tree-toggle")) return

    const link = event.target.closest("a[data-tree-refresh-url]")
    if (!link) return
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return

    this.refreshDocumentTree(link)
  }

  refreshDocumentTree(link) {
    const url = link.dataset.treeRefreshUrl
    if (!url) return

    fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin"
    })
      .then((response) => response.ok ? response.text() : "")
      .then((html) => {
        if (!html) return
        window.Turbo?.renderStreamMessage(html)
      })
  }
}
