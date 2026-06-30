import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "row", "status", "checkbox", "selectedOnly", "empty", "tableBody"]

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
    const document = this.remoteDocumentPayload(event)
    const documentId = document.id

    if (documentId === "") {
      this.queryTarget.value = ""
      this.filter()
      return
    }

    const row = this.rowTargets.find((candidate) => candidate.dataset.documentSetDocumentFilterDocumentId === documentId) || this.createRemoteDocumentRow(document)
    if (!row) return

    const checkbox = row.querySelector("[data-document-set-document-filter-target~='checkbox']")
    if (checkbox) checkbox.checked = true

    this.queryTarget.value = row.dataset.documentSetDocumentFilterSlug || row.dataset.documentSetDocumentFilterSearchText || ""
    this.filter()
    row.hidden = false
    row.scrollIntoView({ block: "nearest" })
  }

  createRemoteDocumentRow(document) {
    if (!this.hasTableBodyTarget || document.id === "") return null

    const existingRow = this.rowTargets.find((candidate) => candidate.dataset.documentSetDocumentFilterDocumentId === document.id)
    if (existingRow) return existingRow

    const row = document.createElement("tr")
    const key = `remote_${document.id}`
    const title = document.title || `文書ID: ${document.id}`
    const slug = document.slug || ""
    const searchText = [title, slug].filter(Boolean).join(" ")

    row.className = "document-set-document-filter__row is-selected"
    row.dataset.documentSetDocumentFilterTarget = "row"
    row.dataset.documentSetDocumentFilterDocumentId = document.id
    row.dataset.documentSetDocumentFilterSlug = slug
    row.dataset.documentSetDocumentFilterSearchText = searchText
    row.dataset.documentCatalogDocumentId = document.id

    row.appendChild(this.buildSelectionCell(key, document.id))
    row.appendChild(this.buildDocumentCell({ title, slug, latestVersionLabel: document.latestVersionLabel, path: document.path }))
    row.appendChild(this.buildSortOrderCell(key))
    row.appendChild(this.buildNoteCell(key))

    this.tableBodyTarget.appendChild(row)
    return row
  }

  buildSelectionCell(key, documentId) {
    const cell = document.createElement("td")
    const hidden = document.createElement("input")
    const checkbox = document.createElement("input")

    hidden.type = "hidden"
    hidden.name = `document_catalog_items[${key}][document_id]`
    hidden.value = documentId

    checkbox.type = "checkbox"
    checkbox.name = `document_catalog_items[${key}][selected]`
    checkbox.value = "1"
    checkbox.checked = true
    checkbox.className = "document-set-document-filter__checkbox"
    checkbox.dataset.documentSetDocumentFilterTarget = "checkbox"
    checkbox.dataset.action = "change->document-set-document-filter#filter"

    cell.appendChild(hidden)
    cell.appendChild(checkbox)
    return cell
  }

  buildDocumentCell({ title, slug, latestVersionLabel, path }) {
    const cell = document.createElement("td")
    const strong = document.createElement("strong")
    const titleNode = path ? document.createElement("a") : document.createElement("span")

    if (path) titleNode.href = path
    titleNode.textContent = title
    strong.appendChild(titleNode)
    cell.appendChild(strong)

    if (slug !== "") {
      cell.appendChild(document.createElement("br"))
      const slugNode = document.createElement("span")
      slugNode.className = "muted"
      slugNode.textContent = `URL識別子: ${slug}`
      cell.appendChild(slugNode)
    }

    if (latestVersionLabel) {
      cell.appendChild(document.createElement("br"))
      const versionNode = document.createElement("span")
      versionNode.className = "muted"
      versionNode.textContent = `最新版: ${latestVersionLabel}`
      cell.appendChild(versionNode)
    }

    return cell
  }

  buildSortOrderCell(key) {
    const cell = document.createElement("td")
    const input = document.createElement("input")

    input.type = "number"
    input.name = `document_catalog_items[${key}][sort_order]`
    input.min = "0"
    input.value = this.rowTargets.length.toString()

    cell.appendChild(input)
    return cell
  }

  buildNoteCell(key) {
    const cell = document.createElement("td")
    const input = document.createElement("input")

    input.type = "text"
    input.name = `document_catalog_items[${key}][note]`
    input.value = ""

    cell.appendChild(input)
    return cell
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

  remoteDocumentPayload(event) {
    const detail = event.detail || {}
    const detailOption = detail.option || detail.item || detail.document || detail.data || detail
    const selectedOption = event.target.selectedOptions && event.target.selectedOptions[0]
    const id = this.valueString(detail.value || detailOption.value || detailOption.id || event.target.value)

    return {
      id,
      title: this.valueString(detailOption.title || detailOption.text || detailOption.label || (selectedOption && selectedOption.textContent) || ""),
      slug: this.valueString(detailOption.slug || detailOption.description || (selectedOption && selectedOption.dataset.slug) || ""),
      latestVersionLabel: this.valueString(detailOption.latest_version_label || detailOption.latestVersionLabel || (selectedOption && selectedOption.dataset.latestVersionLabel) || ""),
      path: this.valueString(detailOption.path || detailOption.url || (selectedOption && selectedOption.dataset.path) || "")
    }
  }

  remoteDocumentValue(event) {
    const value = event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value
    return Array.isArray(value) ? this.normalize(value[0] || "") : this.normalize(value || "")
  }

  valueString(value) {
    const rawValue = Array.isArray(value) ? value[0] : value
    return rawValue === undefined || rawValue === null ? "" : rawValue.toString().trim()
  }

  normalize(value) {
    return value.toString().trim().toLowerCase()
  }
}
