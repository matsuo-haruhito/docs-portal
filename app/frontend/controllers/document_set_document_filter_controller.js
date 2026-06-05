import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "row", "status", "checkbox", "selectedOnly", "empty"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.normalize(this.queryTarget.value)
    const selectedOnly = this.hasSelectedOnlyTarget && this.selectedOnlyTarget.checked
    let visibleCount = 0
    let selectedCount = 0
    const totalCount = this.rowTargets.length

    this.rowTargets.forEach((row) => {
      const checkbox = row.querySelector("[data-document-set-document-filter-target~='checkbox']")
      const selected = checkbox ? checkbox.checked : false
      const searchableText = this.normalize(row.dataset.documentSetDocumentFilterSearchText || row.textContent)
      const matchesQuery = query === "" || searchableText.includes(query)
      const visible = matchesQuery && (!selectedOnly || selected)

      row.hidden = !visible
      row.classList.toggle("is-selected", selected)
      if (selected) selectedCount += 1
      if (visible) visibleCount += 1
    })

    this.updateStatus({ totalCount, visibleCount, selectedCount, query, selectedOnly })
    this.updateEmptyState({ visibleCount, selectedCount, query, selectedOnly })
  }

  pickRemoteDocument(event) {
    const documentId = this.remoteDocumentValue(event)

    if (documentId === "") {
      this.queryTarget.value = ""
      this.filter()
      return
    }

    const row = this.rowTargets.find((candidate) => candidate.dataset.documentSetDocumentFilterDocumentId === documentId)
    if (!row) return

    this.queryTarget.value = row.dataset.documentSetDocumentFilterSlug || row.dataset.documentSetDocumentFilterSearchText || ""
    this.filter()
  }

  updateStatus({ totalCount, visibleCount, selectedCount, query, selectedOnly }) {
    const scopeLabel = selectedOnly ? "選択済みのみ" : "全候補"
    const searchLabel = query === "" ? "検索なし" : "検索中"

    this.statusTargets.forEach((status) => {
      status.textContent = `${scopeLabel} / ${searchLabel}: ${visibleCount}件表示中（選択済み ${selectedCount}件 / 全${totalCount}件）`
    })
  }

  updateEmptyState({ visibleCount, selectedCount, query, selectedOnly }) {
    if (!this.hasEmptyTarget) return

    if (visibleCount > 0) {
      this.emptyTarget.hidden = true
      this.emptyTarget.textContent = ""
      return
    }

    this.emptyTarget.hidden = false

    if (selectedOnly && selectedCount === 0) {
      this.emptyTarget.textContent = "選択済みの文書はありません。"
    } else if (selectedOnly && query !== "") {
      this.emptyTarget.textContent = "選択済み文書の中に検索条件に一致する文書はありません。"
    } else if (query !== "") {
      this.emptyTarget.textContent = "検索条件に一致する文書はありません。"
    } else {
      this.emptyTarget.textContent = "表示できる対象文書はありません。"
    }
  }

  remoteDocumentValue(event) {
    const value = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value
    return Array.isArray(value) ? this.normalize(value[0] || "") : this.normalize(value || "")
  }

  normalize(value) {
    return value.toString().trim().toLowerCase()
  }
}
