import { Controller } from "@hotwired/stimulus"

const TABLE_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableWidth"
const TABLE_COLUMN_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableColumnWidths"
const TABLE_STICKY_HEADER_STORAGE_PREFIX = "docsPortal.previewTableStickyHeader"
const TABLE_STICKY_COLUMN_STORAGE_PREFIX = "docsPortal.previewTableStickyColumn"
const MARKDOWN_TABLE_SELECTOR = [
  ".markdown table",
  ".theme-doc-markdown table",
  ".theme-doc-content table",
  ".docItemContainer table",
  "main table",
  "article table"
].join(", ")
const MIN_COLUMN_WIDTH = 72
const MAX_COLUMN_WIDTH = 960
const frameRefreshTimers = new WeakMap<HTMLIFrameElement, number>()
const frameObservers = new WeakMap<HTMLIFrameElement, MutationObserver>()

function clampColumnWidth(value: number): number {
  return Math.min(MAX_COLUMN_WIDTH, Math.max(MIN_COLUMN_WIDTH, value))
}

function rawFrameLocation(frame: HTMLIFrameElement): string {
  return frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
}

function normalizeSitePath(path: string): string {
  let value = path.toString().replace(/^\/+/, "")
  value = value.replace(/^(?:index|README)\.(?:md|markdown|mdx)$/i, "index")
  value = value.replace(/\/(?:index|README)\.(?:md|markdown|mdx)$/i, "")
  value = value.replace(/\.(md|markdown|mdx)$/i, "")
  value = value.replace(/\/index\.html$/i, "")
  value = value.replace(/\.html$/i, "")
  return value || "index"
}

function previewContextKeyFromBody(frame: HTMLIFrameElement): string | null {
  try {
    return frame.contentDocument?.body?.dataset?.docsPortalPreviewContextKey || null
  } catch (_error) {
    return null
  }
}

function previewContextKeyFromUrl(frame: HTMLIFrameElement): string {
  const rawLocation = rawFrameLocation(frame)

  try {
    const url = new URL(rawLocation, window.location.origin)
    const versionId = url.searchParams.get("version_id") || url.pathname.match(/\/document_versions\/([^/]+)\/site(?:\/|$)/)?.[1]
    const sitePath = url.pathname.match(/\/projects\/[^/]+\/site(?:\/(.*))?$/)?.[1] || url.pathname.match(/\/document_versions\/[^/]+\/site(?:\/(.*))?$/)?.[1] || ""

    if (!versionId) return rawLocation

    return `document_version:${versionId}:${normalizeSitePath(decodeURIComponent(sitePath))}`
  } catch (_error) {
    return rawLocation
  }
}

function previewContextKey(frame: HTMLIFrameElement): string {
  return previewContextKeyFromBody(frame) || previewContextKeyFromUrl(frame)
}

function storageKey(prefix: string, frame: HTMLIFrameElement, index: number): string {
  return `${prefix}:${previewContextKey(frame)}:table:${index}`
}

function readNumber(key: string, fallback: number): number {
  const value = Number(window.localStorage.getItem(key))
  return Number.isFinite(value) ? value : fallback
}

function readTableWidth(frame: HTMLIFrameElement, index: number): number {
  const value = readNumber(storageKey(TABLE_WIDTH_STORAGE_PREFIX, frame, index), 100)
  return value >= 80 && value <= 220 ? value : 100
}

function readTableColumnWidths(frame: HTMLIFrameElement, index: number): number[] {
  try {
    const values = JSON.parse(window.localStorage.getItem(storageKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index)) || "[]")
    return Array.isArray(values) ? values.map((value: unknown) => Number(value)).filter(Number.isFinite) : []
  } catch (_error) {
    return []
  }
}

function writeTableColumnWidths(frame: HTMLIFrameElement, index: number, widths: number[]): void {
  window.localStorage.setItem(storageKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index), JSON.stringify(widths))
}

function readBoolean(prefix: string, frame: HTMLIFrameElement, index: number): boolean {
  return window.localStorage.getItem(storageKey(prefix, frame, index)) === "true"
}

function writeBoolean(prefix: string, frame: HTMLIFrameElement, index: number, enabled: boolean): void {
  window.localStorage.setItem(storageKey(prefix, frame, index), String(enabled))
}

function injectStyle(frameDocument: Document): void {
  if (frameDocument.querySelector("style[data-docs-portal-table-width]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalTableWidth = "true"
  style.textContent = `
    .portal-table-width-frame { margin: 1rem 0; border: 1px solid var(--doc-border, #e5e7eb); border-radius: 12px; background: var(--doc-surface, #fff); overflow: hidden; }
    .portal-table-width-toolbar { margin: 0; border: 0; border-bottom: 1px solid var(--doc-border-soft, #eef2f7); background: var(--doc-bg-soft, #f8fafc); color: var(--doc-text-muted, #64748b); font-size: .9rem; }
    .portal-table-width-toolbar > summary { display: flex; gap: .35rem; align-items: center; justify-content: space-between; min-height: 1.35rem; margin: 0; padding: .08rem .28rem; cursor: pointer; list-style: none; user-select: none; }
    .portal-table-width-toolbar > summary::-webkit-details-marker { display: none; }
    .portal-table-width-toolbar > summary::after { content: "▼"; display: inline-flex; align-items: center; justify-content: center; width: 1.35rem; height: 1.25rem; border: 0; border-radius: 4px; background: transparent; color: var(--doc-primary, #2563eb); font-size: 1rem; line-height: 1; padding: 0; }
    .portal-table-width-toolbar[open] > summary::after { content: "▲"; }
    .portal-table-width-toolbar-title { color: var(--doc-text-soft, #334155); font-size: 1rem; font-weight: 800; line-height: 1.15; }
    .portal-table-width-summary-cue { color: var(--doc-text-muted, #64748b); font-size: .72rem; line-height: 1.2; margin-left: auto; text-align: right; }
    .portal-table-width-toolbar-body { display: flex; gap: .25rem; align-items: center; justify-content: space-between; flex-wrap: wrap; padding: 0 .28rem .18rem; }
    .portal-table-width-toolbar label { display: inline-flex; gap: .28rem; align-items: center; margin: 0; white-space: nowrap; }
    .portal-table-width-toolbar input[type="range"] { width: 132px; accent-color: var(--doc-primary, #2563eb); }
    .portal-table-width-actions { display: inline-flex; gap: .22rem; align-items: center; flex-wrap: wrap; }
    .portal-table-width-button { border: 1px solid var(--doc-primary-border, #bfdbfe); border-radius: 999px; background: var(--doc-surface, #fff); color: var(--doc-primary, #2563eb); cursor: pointer; font: inherit; font-size: .72rem; line-height: 1.15; padding: .13rem .4rem; }
    .portal-table-width-button:hover, .portal-table-width-button:focus, .portal-table-width-button[aria-pressed="true"] { border-color: var(--doc-primary, #2563eb); outline: none; }
    .portal-table-width-button[aria-pressed="true"] { background: var(--doc-primary, #2563eb); color: #fff; }
    .portal-table-width-hint { color: var(--doc-text-muted, #64748b); font-size: .72rem; }
    .portal-table-width-scroll { overflow: auto; max-height: min(70vh, 720px); padding: 0; }
    .portal-table-width-frame table { margin: 0 !important; width: var(--portal-table-width, 100%) !important; min-width: var(--portal-table-width, 100%) !important; max-width: none !important; display: table !important; }
    .portal-table-width-frame th, .portal-table-width-frame td { position: relative; }
    .portal-table-width-frame.has-sticky-header thead th, .portal-table-width-frame.has-sticky-header tr:first-child th { position: sticky; top: 0; z-index: 4; background: var(--doc-bg-soft, #f8fafc); box-shadow: 0 1px 0 var(--doc-border, #e5e7eb); }
    .portal-table-width-frame.has-sticky-header tr:first-child td { position: sticky; top: 0; z-index: 3; background: var(--doc-bg-soft, #f8fafc); box-shadow: 0 1px 0 var(--doc-border, #e5e7eb); }
    .portal-table-width-frame.has-sticky-column tr > :first-child { position: sticky; left: 0; z-index: 2; background: var(--doc-surface, #fff); box-shadow: 1px 0 0 var(--doc-border, #e5e7eb); }
    .portal-table-width-frame.has-sticky-header.has-sticky-column thead tr > :first-child, .portal-table-width-frame.has-sticky-header.has-sticky-column tr:first-child > :first-child { z-index: 6; background: var(--doc-bg-soft, #f8fafc); }
    .portal-table-column-resizer { position: absolute; top: 0; right: -4px; z-index: 7; width: 8px; height: 100%; min-height: 28px; padding: 0; border: 0; border-radius: 0; background: transparent; box-shadow: none; cursor: col-resize; opacity: 0; }
    .portal-table-width-frame:hover .portal-table-column-resizer, .portal-table-column-resizer:hover, .portal-table-column-resizer:focus, .portal-table-column-resizer.is-resizing { opacity: 1; }
    .portal-table-column-resizer::after { content: ""; position: absolute; top: 7px; bottom: 7px; left: 3px; width: 2px; border-radius: 999px; background: transparent; }
    .portal-table-column-resizer:hover::after, .portal-table-column-resizer:focus::after, .portal-table-column-resizer.is-resizing::after { background: var(--doc-primary, #2563eb); box-shadow: 0 0 0 3px rgb(37 99 235 / 14%); }
    .portal-table-width-frame.is-column-resizing, .portal-table-width-frame.is-column-resizing * { cursor: col-resize !important; user-select: none; }
    @media (max-width: 720px) {
      .portal-table-width-toolbar > summary, .portal-table-width-toolbar-body { align-items: flex-start; flex-direction: column; }
      .portal-table-width-summary-cue { margin-left: 0; text-align: left; }
      .portal-table-width-toolbar input[type="range"] { width: 190px; }
    }
  `
  frameDocument.head?.appendChild(style)
}

function tableColumnCount(table: HTMLTableElement): number {
  return Math.max(...Array.from(table.rows).map((row) => row.cells.length), 0)
}

function ensureColgroup(frameDocument: Document, table: HTMLTableElement, columnCount: number): HTMLElement {
  let colgroup = table.querySelector("colgroup[data-docs-portal-column-widths]")
  if (!colgroup) {
    colgroup = frameDocument.createElement("colgroup")
    ;(colgroup as HTMLElement).dataset.docsPortalColumnWidths = "true"
    table.prepend(colgroup)
  }

  while (colgroup.children.length < columnCount) colgroup.appendChild(frameDocument.createElement("col"))
  while (colgroup.children.length > columnCount) colgroup.lastElementChild?.remove()
  return colgroup as HTMLElement
}

function applyColumnWidths(table: HTMLTableElement, colgroup: HTMLElement, widths: number[]): void {
  table.style.tableLayout = widths.some((width) => Number.isFinite(width)) ? "fixed" : ""
  Array.from(colgroup.children).forEach((col, index) => {
    const width = widths[index]
    ;(col as HTMLElement).style.width = Number.isFinite(width) ? `${clampColumnWidth(width)}px` : ""
  })
}

function tableLooksLikeMarkdownContent(table: HTMLTableElement): boolean {
  if (!table.rows.length || table.closest(".portal-table-width-frame")) return false
  if (table.closest("nav, header, footer, .navbar, .pagination-nav, .theme-doc-toc-desktop")) return false
  return true
}

function markdownTables(frameDocument: Document): HTMLTableElement[] {
  return Array.from(frameDocument.querySelectorAll<HTMLTableElement>(MARKDOWN_TABLE_SELECTOR)).filter(tableLooksLikeMarkdownContent)
}

function tableIndex(frameDocument: Document, table: HTMLTableElement): number {
  const existingIndex = Number((table as HTMLElement).dataset.docsPortalTableIndex)
  if (Number.isInteger(existingIndex) && existingIndex >= 0) return existingIndex

  const index = markdownTables(frameDocument).indexOf(table)
  ;(table as HTMLElement).dataset.docsPortalTableIndex = String(index)
  return index
}

function copyTablePreferenceMetadata(wrapper: HTMLElement, table: HTMLTableElement): void {
  const metadata: Record<string, string | undefined> = {
    docsPortalDocumentVersion: (table as HTMLElement).dataset.docsPortalDocumentVersion,
    docsPortalSitePath: (table as HTMLElement).dataset.docsPortalSitePath,
    docsPortalTableIndex: (table as HTMLElement).dataset.docsPortalTableIndex,
    railsTablePreferencesTableKey: (table as HTMLElement).dataset.railsTablePreferencesTableKey
  }

  Object.entries(metadata).forEach(([key, value]) => {
    if (value) wrapper.dataset[key] = value
  })
}

export default class extends Controller {
  private boundRefresh!: () => void

  connect(): void {
    this.boundRefresh = this.refresh.bind(this)
    document.addEventListener("turbo:load", this.boundRefresh)
    document.addEventListener("turbo:render", this.boundRefresh)
    this.refresh()
  }

  disconnect(): void {
    document.removeEventListener("turbo:load", this.boundRefresh)
    document.removeEventListener("turbo:render", this.boundRefresh)
  }

  private refresh(): void {
    document.querySelectorAll<HTMLIFrameElement>("iframe.site-viewer-frame").forEach((frame) => {
      if (frame.dataset.tableWidthReady !== "true") {
        frame.dataset.tableWidthReady = "true"
        frame.addEventListener("load", () => this.enhanceFrame(frame))
      }
      this.enhanceFrame(frame)
    })
  }

  private scheduleFrameEnhancement(frame: HTMLIFrameElement): void {
    window.clearTimeout(frameRefreshTimers.get(frame))
    frameRefreshTimers.set(frame, window.setTimeout(() => this.enhanceFrame(frame), 80))
  }

  private observeFrame(frame: HTMLIFrameElement, frameDocument: Document): void {
    if (frameObservers.has(frame)) return

    const Observer = (frame.contentWindow as unknown as { MutationObserver?: typeof MutationObserver })?.MutationObserver || window.MutationObserver
    if (!Observer) return

    const observer = new Observer(() => this.scheduleFrameEnhancement(frame))
    observer.observe(frameDocument.body, { childList: true, subtree: true })
    frameObservers.set(frame, observer)
  }

  private notifyTablesEnhanced(frame: HTMLIFrameElement): void {
    frame.dispatchEvent(new CustomEvent("docs-portal:preview-tables-enhanced"))
  }

  private enhanceFrame(frame: HTMLIFrameElement): void {
    try {
      const frameDocument = frame.contentDocument
      if (!frameDocument?.body) return

      injectStyle(frameDocument)
      this.observeFrame(frame, frameDocument)

      const tables = markdownTables(frameDocument).filter((table) => !table.closest(".portal-table-width-frame"))
      tables.forEach((table) => this.wrapTable(frame, frameDocument, table, tableIndex(frameDocument, table)))
      this.notifyTablesEnhanced(frame)
    } catch (_error) {
      // Cross-origin fallback
    }
  }

  private wrapTable(frame: HTMLIFrameElement, frameDocument: Document, table: HTMLTableElement, index: number): void {
    const width = readTableWidth(frame, index)
    const stickyHeader = readBoolean(TABLE_STICKY_HEADER_STORAGE_PREFIX, frame, index)
    const stickyColumn = readBoolean(TABLE_STICKY_COLUMN_STORAGE_PREFIX, frame, index)
    const wrapper = frameDocument.createElement("div")
    wrapper.className = "portal-table-width-frame"
    copyTablePreferenceMetadata(wrapper, table)
    wrapper.dataset.docsPortalTableIndex = String(index)
    wrapper.style.setProperty("--portal-table-width", `${width}%`)

    const toolbar = frameDocument.createElement("details")
    toolbar.className = "portal-table-width-toolbar"
    const summary = frameDocument.createElement("summary")
    const summaryTitle = frameDocument.createElement("span")
    summaryTitle.className = "portal-table-width-toolbar-title"
    summaryTitle.textContent = "表ツール"
    const summaryCue = frameDocument.createElement("span")
    summaryCue.className = "portal-table-width-summary-cue"
    summaryCue.textContent = "横スクロール・列幅調整できます"
    summary.append(summaryTitle, summaryCue)

    const toolbarBody = frameDocument.createElement("div")
    toolbarBody.className = "portal-table-width-toolbar-body"

    const label = frameDocument.createElement("label")
    label.textContent = "表の幅"
    const range = frameDocument.createElement("input")
    range.type = "range"
    range.min = "80"
    range.max = "220"
    range.step = "10"
    range.value = String(width)
    const valueText = frameDocument.createElement("span")
    valueText.textContent = `${width}%`
    label.appendChild(range)
    label.appendChild(valueText)

    const actions = frameDocument.createElement("span")
    actions.className = "portal-table-width-actions"
    const fitButton = this.createButton(frameDocument, "標準")
    const wideButton = this.createButton(frameDocument, "広め")
    const stickyHeaderButton = this.createButton(frameDocument, stickyHeader ? "ヘッダー固定中" : "ヘッダー固定")
    const stickyColumnButton = this.createButton(frameDocument, stickyColumn ? "先頭列固定中" : "先頭列固定")
    const resetColumnsButton = this.createButton(frameDocument, "列幅リセット")
    const hint = frameDocument.createElement("span")
    hint.className = "portal-table-width-hint"
    hint.textContent = "列境界をドラッグできます"
    actions.append(fitButton, wideButton, stickyHeaderButton, stickyColumnButton, resetColumnsButton, hint)
    toolbarBody.append(label, actions)
    toolbar.append(summary, toolbarBody)

    const scroll = frameDocument.createElement("div")
    scroll.className = "portal-table-width-scroll"
    scroll.setAttribute("aria-label", "表は横スクロールできます")
    table.parentNode!.insertBefore(wrapper, table)
    scroll.appendChild(table)
    wrapper.append(toolbar, scroll)
    this.applyStickyHeader(wrapper, stickyHeaderButton, stickyHeader)
    this.applyStickyColumn(wrapper, stickyColumnButton, stickyColumn)

    const applyWidth = (nextWidth: number): void => {
      wrapper.style.setProperty("--portal-table-width", `${nextWidth}%`)
      range.value = String(nextWidth)
      valueText.textContent = `${nextWidth}%`
      window.localStorage.setItem(storageKey(TABLE_WIDTH_STORAGE_PREFIX, frame, index), String(nextWidth))
    }

    range.addEventListener("input", () => applyWidth(Number(range.value)))
    fitButton.addEventListener("click", () => applyWidth(100))
    wideButton.addEventListener("click", () => applyWidth(160))
    stickyHeaderButton.addEventListener("click", () => {
      const enabled = !wrapper.classList.contains("has-sticky-header")
      this.applyStickyHeader(wrapper, stickyHeaderButton, enabled)
      writeBoolean(TABLE_STICKY_HEADER_STORAGE_PREFIX, frame, index, enabled)
    })
    stickyColumnButton.addEventListener("click", () => {
      const enabled = !wrapper.classList.contains("has-sticky-column")
      this.applyStickyColumn(wrapper, stickyColumnButton, enabled)
      writeBoolean(TABLE_STICKY_COLUMN_STORAGE_PREFIX, frame, index, enabled)
    })
    resetColumnsButton.addEventListener("click", () => this.resetColumnWidths(frame, index, table))
    this.setupColumnResizers(frame, frameDocument, table, index, wrapper)
  }

  private createButton(frameDocument: Document, text: string): HTMLButtonElement {
    const button = frameDocument.createElement("button")
    button.type = "button"
    button.className = "portal-table-width-button"
    button.textContent = text
    return button
  }

  private applyStickyHeader(wrapper: HTMLElement, button: HTMLButtonElement, enabled: boolean): void {
    wrapper.classList.toggle("has-sticky-header", enabled)
    button.textContent = enabled ? "ヘッダー固定中" : "ヘッダー固定"
    button.setAttribute("aria-pressed", String(enabled))
  }

  private applyStickyColumn(wrapper: HTMLElement, button: HTMLButtonElement, enabled: boolean): void {
    wrapper.classList.toggle("has-sticky-column", enabled)
    button.textContent = enabled ? "先頭列固定中" : "先頭列固定"
    button.setAttribute("aria-pressed", String(enabled))
  }

  private resetColumnWidths(frame: HTMLIFrameElement, index: number, table: HTMLTableElement): void {
    window.localStorage.removeItem(storageKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index))
    table.querySelector("colgroup[data-docs-portal-column-widths]")?.remove()
    table.style.tableLayout = ""
  }

  private setupColumnResizers(frame: HTMLIFrameElement, frameDocument: Document, table: HTMLTableElement, tblIndex: number, wrapper: HTMLElement): void {
    const columnCount = tableColumnCount(table)
    if (columnCount <= 1) return

    const colgroup = ensureColgroup(frameDocument, table, columnCount)
    const widths = readTableColumnWidths(frame, tblIndex)
    applyColumnWidths(table, colgroup, widths)

    Array.from(table.rows).forEach((row) => {
      Array.from(row.cells).forEach((cell, columnIndex) => {
        if (columnIndex >= columnCount - 1) return
        this.attachColumnResizer(frame, frameDocument, cell, columnIndex, tblIndex, table, colgroup, widths, wrapper)
      })
    })
  }

  private attachColumnResizer(frame: HTMLIFrameElement, frameDocument: Document, cell: HTMLTableCellElement, columnIndex: number, tblIndex: number, table: HTMLTableElement, colgroup: HTMLElement, widths: number[], wrapper: HTMLElement): void {
    if (cell.querySelector(`.portal-table-column-resizer[data-column-index="${columnIndex}"]`)) return

    const resizer = frameDocument.createElement("button")
    resizer.type = "button"
    resizer.className = "portal-table-column-resizer"
    resizer.dataset.columnIndex = String(columnIndex)
    resizer.setAttribute("aria-label", `${columnIndex + 1}列目の幅を調整`)
    cell.appendChild(resizer)

    let dragging = false
    let startX = 0
    let startWidth = 0
    const stopDragging = (): void => {
      dragging = false
      wrapper.classList.remove("is-column-resizing")
      wrapper.querySelectorAll(".portal-table-column-resizer.is-resizing").forEach((activeResizer) => activeResizer.classList.remove("is-resizing"))
    }
    const resizeColumn = (clientX: number): void => {
      widths[columnIndex] = clampColumnWidth(startWidth + clientX - startX)
      applyColumnWidths(table, colgroup, widths)
      writeTableColumnWidths(frame, tblIndex, widths)
    }

    resizer.addEventListener("pointerdown", (event) => {
      dragging = true
      startX = event.clientX
      startWidth = colgroup.children[columnIndex]?.getBoundingClientRect().width || cell.getBoundingClientRect().width
      wrapper.classList.add("is-column-resizing")
      wrapper.querySelectorAll(`.portal-table-column-resizer[data-column-index="${columnIndex}"]`).forEach((sameColumnResizer) => sameColumnResizer.classList.add("is-resizing"))
      resizer.setPointerCapture(event.pointerId)
      event.preventDefault()
      event.stopPropagation()
    })
    resizer.addEventListener("pointermove", (event) => {
      if (dragging) resizeColumn(event.clientX)
    })
    resizer.addEventListener("pointerup", stopDragging)
    resizer.addEventListener("pointercancel", stopDragging)
    resizer.addEventListener("keydown", (event) => {
      if (!["ArrowLeft", "ArrowRight", "Home"].includes(event.key)) return
      event.preventDefault()
      const currentWidth = colgroup.children[columnIndex]?.getBoundingClientRect().width || cell.getBoundingClientRect().width
      const step = event.shiftKey ? 40 : 16
      const nextWidth = event.key === "Home" ? MIN_COLUMN_WIDTH : event.key === "ArrowLeft" ? currentWidth - step : currentWidth + step
      widths[columnIndex] = clampColumnWidth(nextWidth)
      applyColumnWidths(table, colgroup, widths)
      writeTableColumnWidths(frame, tblIndex, widths)
    })
  }
}
