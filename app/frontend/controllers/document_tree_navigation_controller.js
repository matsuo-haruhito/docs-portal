import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    document.addEventListener("click", this.onClick, true)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick, true)
    this.clearRefreshCue(this.refreshRequestId)
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

    const requestId = this.beginRefresh()

    fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) throw new Error("Document tree refresh failed")
        return response.text()
      })
      .then((html) => {
        if (!this.isCurrentRefresh(requestId)) return
        if (html) window.Turbo?.renderStreamMessage(html)
        this.clearRefreshCue(requestId)
      })
      .catch(() => {
        if (!this.isCurrentRefresh(requestId)) return
        this.showRefreshCue(
          "error",
          "文書ツリーを更新できませんでした。ページを再読み込みするか、本文側の表示を確認してください。"
        )
      })
  }

  beginRefresh() {
    this.refreshRequestId = (this.refreshRequestId || 0) + 1
    this.showRefreshCue("loading", "文書ツリーを更新しています。")
    return this.refreshRequestId
  }

  isCurrentRefresh(requestId) {
    return requestId === this.refreshRequestId
  }

  showRefreshCue(state, message) {
    const container = this.refreshCueContainer()
    if (!container) return

    const cue = this.refreshCueElement(container)
    cue.textContent = message
    cue.dataset.documentTreeRefreshCue = state
    cue.className = `muted document-tree-refresh-cue document-tree-refresh-cue--${state}`
    cue.setAttribute("role", state === "error" ? "alert" : "status")
    cue.setAttribute("aria-live", state === "error" ? "assertive" : "polite")
  }

  clearRefreshCue(requestId) {
    if (!this.isCurrentRefresh(requestId)) return

    const cue = this.element.querySelector("[data-document-tree-refresh-cue]")
    cue?.remove()
  }

  refreshCueContainer() {
    return this.element.querySelector("[data-sidebar-content]") || document.querySelector("[data-sidebar-content]")
  }

  refreshCueElement(container) {
    const existingCue = container.querySelector("[data-document-tree-refresh-cue]")
    if (existingCue) return existingCue

    const cue = document.createElement("p")
    const treePanel = container.querySelector("#document_tree_panel")

    if (treePanel) {
      container.insertBefore(cue, treePanel)
    } else {
      container.prepend(cue)
    }

    return cue
  }
}
