import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  private boundOnClick!: (event: MouseEvent) => void
  private refreshRequestId = 0

  connect(): void {
    this.boundOnClick = this.onClick.bind(this)
    document.addEventListener("click", this.boundOnClick, true)
  }

  disconnect(): void {
    document.removeEventListener("click", this.boundOnClick, true)
    this.clearRefreshCue(this.refreshRequestId)
  }

  private onClick(event: MouseEvent): void {
    if ((event.target as Element).closest(".tree-toggle")) return

    const link = (event.target as Element).closest<HTMLAnchorElement>("a[data-tree-refresh-url]")
    if (!link) return
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return

    this.refreshDocumentTree(link)
  }

  private refreshDocumentTree(link: HTMLElement): void {
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
        if (html) window.Turbo?.visit?.(window.location.href, { action: "replace" })
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

  private beginRefresh(): number {
    this.refreshRequestId = (this.refreshRequestId || 0) + 1
    this.showRefreshCue("loading", "文書ツリーを更新しています。")
    return this.refreshRequestId
  }

  private isCurrentRefresh(requestId: number): boolean {
    return requestId === this.refreshRequestId
  }

  private showRefreshCue(state: string, message: string): void {
    const container = this.refreshCueContainer()
    if (!container) return

    const cue = this.refreshCueElement(container)
    cue.textContent = message
    cue.dataset.documentTreeRefreshCue = state
    cue.className = `muted document-tree-refresh-cue document-tree-refresh-cue--${state}`
    cue.setAttribute("role", state === "error" ? "alert" : "status")
    cue.setAttribute("aria-live", state === "error" ? "assertive" : "polite")
  }

  private clearRefreshCue(requestId: number): void {
    if (!this.isCurrentRefresh(requestId)) return

    const container = this.refreshCueContainer()
    const cue = container?.querySelector("[data-document-tree-refresh-cue]")
    cue?.remove()
  }

  private refreshCueContainer(): HTMLElement | null {
    return this.element.querySelector<HTMLElement>("[data-sidebar-content]") || document.querySelector<HTMLElement>("[data-sidebar-content]")
  }

  private refreshCueElement(container: HTMLElement): HTMLElement {
    const existingCue = container.querySelector<HTMLElement>("[data-document-tree-refresh-cue]")
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
