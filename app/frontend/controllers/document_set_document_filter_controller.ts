import { Controller } from "@hotwired/stimulus"

interface RemoteDocumentPayload {
  id: string
  title: string
  slug: string
  latestVersionLabel: string
  path: string
}

export default class extends Controller {
  static targets = ["query", "row", "status", "checkbox", "selectedOnly", "empty", "tableBody"]

  declare readonly queryTarget: HTMLInputElement
  declare readonly rowTargets: HTMLElement[]
  declare readonly statusTargets: HTMLElement[]
  declare readonly hasSelectedOnlyTarget: boolean
  declare readonly selectedOnlyTarget: HTMLInputElement
  declare readonly hasEmptyTarget: boolean
  declare readonly emptyTarget: HTMLElement
  declare readonly hasTableBodyTarget: boolean
  declare readonly tableBodyTarget: HTMLElement

  connect(): void {
    this.filter()
  }

  filter(): void {
    const query = this.normalize(this.queryTarget.value)
    const selectedOnly = this.hasSelectedOnlyTarget && this.selectedOnlyTarget.checked
    let visibleCount = 0
    let selectedCount = 0
    const totalCount = this.rowTargets.length

    this.rowTargets.forEach((row) => {
      const checkbox = row.querySelector<HTMLInputElement>("[data-document-set-document-filter-target~='checkbox']")
      const selected = checkbox ? checkbox.checked : false
      const searchableText = this.normalize(row.dataset.documentSetDocumentFilterSearchText || row.textContent || "")
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

  pickRemoteDocument(event: Event): void {
    const remoteDocument = this.remoteDocumentPayload(event)
    const documentId = remoteDocument.id

    if (documentId === "") {
      this.queryTarget.value = ""
      this.filter()
      return
    }

    const row = this.rowTargets.find((candidate) => candidate.dataset.documentSetDocumentFilterDocumentId === documentId) || this.createRemoteDocumentRow(remoteDocument)
    if (!row) return

    const checkbox = row.querySelector<HTMLInputElement>("[data-document-set-document-filter-target~='checkbox']")
    if (checkbox) checkbox.checked = true

    this.queryTarget.value = row.dataset.documentSetDocumentFilterSlug || row.dataset.documentSetDocumentFilterSearchText || ""
    this.filter()
    row.hidden = false
    row.scrollIntoView({ block: "nearest" })
  }

  private createRemoteDocumentRow(remoteDocument: RemoteDocumentPayload): HTMLElement | null {
    if (!this.hasTableBodyTarget || remoteDocument.id === "") return null

    const existingRow = this.rowTargets.find((candidate) => candidate.dataset.documentSetDocumentFilterDocumentId === remoteDocument.id)
    if (existingRow) return existingRow

    const row = document.createElement("tr")
    const key = `remote_${remoteDocument.id}`
    const title = remoteDocument.title || `文書ID: ${remoteDocument.id}`
    const slug = remoteDocument.slug || ""
    const searchText = [title, slug].filter(Boolean).join(" ")

    row.className = "document-set-document-filter__row is-selected"
    row.dataset.documentSetDocumentFilterTarget = "row"
    row.dataset.documentSetDocumentFilterDocumentId = remoteDocument.id
    row.dataset.documentSetDocumentFilterSlug = slug
    row.dataset.documentSetDocumentFilterSearchText = searchText
    row.dataset.documentCatalogDocumentId = remoteDocument.id

    row.appendChild(this.buildSelectionCell(key, remoteDocument.id))
    row.appendChild(this.buildDocumentCell({ title, slug, latestVersionLabel: remoteDocument.latestVersionLabel, path: remoteDocument.path }))
    row.appendChild(this.buildSortOrderCell(key))
    row.appendChild(this.buildNoteCell(key))

    this.tableBodyTarget.appendChild(row)
    return row
  }

  private buildSelectionCell(key: string, documentId: string): HTMLElement {
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

  private buildDocumentCell({ title, slug, latestVersionLabel, path }: { title: string; slug: string; latestVersionLabel: string; path: string }): HTMLElement {
    const cell = document.createElement("td")
    const strong = document.createElement("strong")
    const titleNode = path ? document.createElement("a") : document.createElement("span")

    if (path && titleNode instanceof HTMLAnchorElement) titleNode.href = path
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

  private buildSortOrderCell(key: string): HTMLElement {
    const cell = document.createElement("td")
    const input = document.createElement("input")

    input.type = "number"
    input.name = `document_catalog_items[${key}][sort_order]`
    input.min = "0"
    input.value = this.rowTargets.length.toString()

    cell.appendChild(input)
    return cell
  }

  private buildNoteCell(key: string): HTMLElement {
    const cell = document.createElement("td")
    const input = document.createElement("input")

    input.type = "text"
    input.name = `document_catalog_items[${key}][note]`
    input.value = ""

    cell.appendChild(input)
    return cell
  }

  private updateStatus({ totalCount, visibleCount, selectedCount, query, selectedOnly }: { totalCount: number; visibleCount: number; selectedCount: number; query: string; selectedOnly: boolean }): void {
    const scopeLabel = selectedOnly ? "選択済みのみ" : "全候補"
    const searchLabel = query === "" ? "検索なし" : "検索中"

    this.statusTargets.forEach((status) => {
      status.textContent = `${scopeLabel} / ${searchLabel}: ${visibleCount}件表示中（選択済み ${selectedCount}件 / 全${totalCount}件）`
    })
  }

  private updateEmptyState({ visibleCount, selectedCount, query, selectedOnly }: { visibleCount: number; selectedCount: number; query: string; selectedOnly: boolean }): void {
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

  private remoteDocumentPayload(event: Event): RemoteDocumentPayload {
    const detail = (event as CustomEvent).detail || {}
    const detailOption = detail.option || detail.item || detail.document || detail.data || detail
    const target = event.target as HTMLSelectElement
    const selectedOption = target.selectedOptions?.[0]
    const id = this.valueString(detail.value || detailOption.value || detailOption.id || target.value)

    return {
      id,
      title: this.valueString(detailOption.title || detailOption.text || detailOption.label || selectedOption?.textContent || ""),
      slug: this.valueString(detailOption.slug || detailOption.description || selectedOption?.dataset.slug || ""),
      latestVersionLabel: this.valueString(detailOption.latest_version_label || detailOption.latestVersionLabel || selectedOption?.dataset.latestVersionLabel || ""),
      path: this.valueString(detailOption.path || detailOption.url || selectedOption?.dataset.path || "")
    }
  }

  private valueString(value: unknown): string {
    const rawValue = Array.isArray(value) ? value[0] : value
    return rawValue === undefined || rawValue === null ? "" : rawValue.toString().trim()
  }

  private normalize(value: string): string {
    return value.toString().trim().toLowerCase()
  }
}
