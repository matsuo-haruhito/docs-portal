import { Controller } from "@hotwired/stimulus"

const TABLE_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableWidth"
const TABLE_COLUMN_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableColumnWidths"
const TABLE_STICKY_HEADER_STORAGE_PREFIX = "docsPortal.previewTableStickyHeader"
const TABLE_STICKY_COLUMN_STORAGE_PREFIX = "docsPortal.previewTableStickyColumn"
const MIN_COLUMN_WIDTH = 72
const MAX_COLUMN_WIDTH = 960

function clampColumnWidth(value) {
  return Math.min(MAX_COLUMN_WIDTH, Math.max(MIN_COLUMN_WIDTH, value))
}

function storageKey(prefix, frame, index) {
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${prefix}:${url}:table:${index}`
}

function readNumber(key, fallback) {
  const value = Number(window.localStorage.getItem(key))
  return Number.isFinite(value) ? value : fallback
}

function readTableWidth(frame, index) {
  const value = readNumber(storageKey(TABLE_WIDTH_STORAGE_PREFIX, frame, index), 100)
  return value >= 80 && value <= 220 ? value : 100
}

function readTableColumnWidths(frame, index) {
  try {
    const values = JSON.parse(window.localStorage.getItem(storageKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index)) || "[]")
    return Array.isArray(values) ? values.map((value) => Number(value)).filter(Number.isFinite) : []
  } catch (_error) {
    return []
  }
}

function writeTableColumnWidths(frame, index, widths) {
  window.localStorage.setItem(storageKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index), JSON.stringify(widths))
}

function readBoolean(prefix, frame, index) {
  return window.localStorage.getItem(storageKey(prefix, frame, index)) === "true"
}

function writeBoolean(prefix, frame, index, enabled) {
  window.localStorage.setItem(storageKey(prefix, frame, index), String(enabled))
}

function injectStyle(frameDocument) {
  if (frameDocument.querySelector("style[data-docs-portal-table-width]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalTableWidth = "true"
  style.textContent = `
    .portal-table-width-frame { margin: 1rem 0; border: 1px solid var(--doc-border, #e5e7eb); border-radius: 12px; background: var(--doc-surface, #fff); overflow: hidden; }
    .portal-table-width-toolbar { display: flex; gap: .55rem; align-items: center; justify-content: space-between; flex-wrap: wrap; padding: .55rem .75rem; border-bottom: 1px solid var(--doc-border-soft, #eef2f7); background: var(--doc-bg-soft, #f8fafc); color: var(--doc-text-muted, #64748b); font-size: .82rem; }
    .portal-table-width-toolbar label { display: inline-flex; gap: .45rem; align-items: center; margin: 0; white-space: nowrap; }
    .portal-table-width-toolbar input[type="range"] { width: 160px; accent-color: var(--doc-primary, #2563eb); }
    .portal-table-width-actions { display: inline-flex; gap: .35rem; align-items: center; flex-wrap: wrap; }
    .portal-table-width-button { border: 1px solid var(--doc-primary-border, #bfdbfe); border-radius: 999px; background: var(--doc-surface, #fff); color: var(--doc-primary, #2563eb); cursor: pointer; font: inherit; font-size: .78rem; padding: .24rem .58rem; }
    .portal-table-width-button:hover, .portal-table-width-button:focus, .portal-table-width-button[aria-pressed="true"] { border-color: var(--doc-primary, #2563eb); outline: none; }
    .portal-table-width-button[aria-pressed="true"] { background: var(--doc-primary, #2563eb); color: #fff; }
    .portal-table-width-hint { color: var(--doc-text-muted, #64748b); font-size: .78rem; }
    .portal-table-width-scroll { overflow: auto; max-height: min(70vh, 720px); padding: .65rem; }
    .portal-table-width-frame table { margin: 0 !important; width: var(--portal-table-width, 100%) !important; min-width: var(--portal-table-width, 100%) !important; max-width: none !important; display: table !important; }
    .portal-table-width-frame th, .portal-table-width-frame td { position: relative; }
    .portal-table-width-frame.has-sticky-header thead th, .portal-table-width-frame.has-sticky-header tr:first-child th { position: sticky; top: 0; z-index: 4; background: var(--doc-bg-soft, #f8fafc); box-shadow: 0 1px 0 var(--doc-border, #e5e7eb); }
    .portal-table-width-frame.has-sticky-header tr:first-child td { position: sticky; top: 0; z-index: 3; background: var(--doc-bg-soft, #f8fafc); box-shadow: 0 1px 0 var(--doc-border, #e5e7eb); }
    .portal-table-width-frame.has-sticky-column tr > :first-child { position: sticky; left: 0; z-index: 2; background: var(--doc-surface, #fff); box-shadow: 1px 0 0 var(--doc-border, #e5e7eb); }
    .portal-table-width-frame.has-sticky-header.has-sticky-column thead tr > :first-child, .portal-table-width-frame.has-sticky-header.has-sticky-column tr:first-child > :first-child { z-index: 6; background: var(--doc-bg-soft, #f8fafc); }
    .portal-table-column-resizer { position: absolute; top: 0; right: -4px; z-index: 7; width: 8px; height: 100%; min-height: 28px; padding: 0; border: 0; border-radius: 0; background: transparent; box-shadow: none; cursor: col-resize; }
    .portal-table-column-resizer::after { content: ""; position: absolute; top: 7px; bottom: 7px; left: 3px; width: 2px; border-radius: 999px; background: transparent; }
    .portal-table-column-resizer:hover::after, .portal-table-column-resizer:focus::after, .portal-table-column-resizer.is-resizing::after { background: var(--doc-primary, #2563eb); box-shadow: 0 0 0 3px rgb(37 99 235 / 14%); }
    .portal-table-width-frame.is-column-resizing, .portal-table-width-frame.is-column-resizing * { cursor: col-resize !important; user-select: none; }
    @media (max-width: 720px) {
      .portal-table-width-toolbar { align-items: flex-start; flex-direction: column; }
      .portal-table-width-toolbar input[type="range"] { width: 190px; }
    }
  `
  frameDocument.head?.appendChild(style)
}

function tableColumnCount(table) {
  return Math.max(...Array.from(table.rows).map((row) => row.cells.length), 0)
}

function ensureColgroup(frameDocument, table, columnCount) {
  let colgroup = table.querySelector("colgroup[data-docs-portal-column-widths]")
  if (!colgroup) {
    colgroup = frameDocument.createElement("colgroup")
    colgroup.dataset.docsPortalColumnWidths = "true"
    table.prepend(colgroup)
  }

  while (colgroup.children.length < columnCount) colgroup.appendChild(frameDocument.createElement("col"))
  while (colgroup.children.length > columnCount) colgroup.lastElementChild?.remove()
  return colgroup
}

function applyColumnWidths(table, colgroup, widths) {
  table.style.tableLayout = widths.some((width) => Number.isFinite(width)) ? "fixed" : ""
  Array.from(colgroup.children).forEach((col, index) => {
    const width = widths[index]
    col.style.width = Number.isFinite(width) ? `${clampColumnWidth(width)}px` : ""
  })
}

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
    document.querySelectorAll("iframe.site-viewer-frame").forEach((frame) => {
      if (frame.dataset.tableWidthReady !== "true") {
        frame.dataset.tableWidthReady = "true"
        frame.addEventListener("load", () => this.enhanceFrame(frame))
      }
      this.enhanceFrame(frame)
    })
  }

  enhanceFrame(frame) {
    try {
      const frameDocument = frame.contentDocument
      if (!frameDocument?.body) return

      injectStyle(frameDocument)
      const tables = Array.from(frameDocument.querySelectorAll(".markdown table, .theme-doc-markdown table, article table"))
        .filter((table) => !table.closest(".portal-table-width-frame"))

      tables.forEach((table, index) => this.wrapTable(frame, frameDocument, table, index))
    } catch (_error) {
      // Cross-origin fallback: if the preview ever becomes external, keep the viewer usable.
    }
  }

  wrapTable(frame, frameDocument, table, index) {
    const width = readTableWidth(frame, index)
    const stickyHeader = readBoolean(TABLE_STICKY_HEADER_STORAGE_PREFIX, frame, index)
    const stickyColumn = readBoolean(TABLE_STICKY_COLUMN_STORAGE_PREFIX, frame, index)
    const wrapper = frameDocument.createElement("div")
    wrapper.className = "portal-table-width-frame"
    wrapper.style.setProperty("--portal-table-width", `${width}%`)

    const toolbar = frameDocument.createElement("div")
    toolbar.className = "portal-table-width-toolbar"
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
    const fitButton = this.button(frameDocument, "標準")
    const wideButton = this.button(frameDocument, "広め")
    const stickyHeaderButton = this.button(frameDocument, stickyHeader ? "ヘッダー固定中" : "ヘッダー固定")
    const stickyColumnButton = this.button(frameDocument, stickyColumn ? "先頭列固定中" : "先頭列固定")
    const resetColumnsButton = this.button(frameDocument, "列幅リセット")
    const hint = frameDocument.createElement("span")
    hint.className = "portal-table-width-hint"
    hint.textContent = "列境界をドラッグできます"
    actions.append(fitButton, wideButton, stickyHeaderButton, stickyColumnButton, resetColumnsButton, hint)
    toolbar.append(label, actions)

    const scroll = frameDocument.createElement("div")
    scroll.className = "portal-table-width-scroll"
    table.parentNode.insertBefore(wrapper, table)
    scroll.appendChild(table)
    wrapper.append(toolbar, scroll)
    this.applyStickyHeader(wrapper, stickyHeaderButton, stickyHeader)
    this.applyStickyColumn(wrapper, stickyColumnButton, stickyColumn)

    const applyWidth = (nextWidth) => {
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

  button(frameDocument, text) {
    const button = frameDocument.createElement("button")
    button.type = "button"
    button.className = "portal-table-width-button"
    button.textContent = text
    return button
  }

  applyStickyHeader(wrapper, button, enabled) {
    wrapper.classList.toggle("has-sticky-header", enabled)
    button.textContent = enabled ? "ヘッダー固定中" : "ヘッダー固定"
    button.setAttribute("aria-pressed", String(enabled))
  }

  applyStickyColumn(wrapper, button, enabled) {
    wrapper.classList.toggle("has-sticky-column", enabled)
    button.textContent = enabled ? "先頭列固定中" : "先頭列固定"
    button.setAttribute("aria-pressed", String(enabled))
  }

  resetColumnWidths(frame, index, table) {
    window.localStorage.removeItem(storageKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index))
    table.querySelector("colgroup[data-docs-portal-column-widths]")?.remove()
    table.style.tableLayout = ""
  }

  setupColumnResizers(frame, frameDocument, table, tableIndex, wrapper) {
    const columnCount = tableColumnCount(table)
    if (columnCount <= 1) return

    const colgroup = ensureColgroup(frameDocument, table, columnCount)
    const widths = readTableColumnWidths(frame, tableIndex)
    applyColumnWidths(table, colgroup, widths)
    const headerRow = table.tHead?.rows?.[0] || table.rows[0]
    if (!headerRow) return

    Array.from(headerRow.cells).forEach((cell, columnIndex) => {
      if (columnIndex >= columnCount - 1) return
      const resizer = frameDocument.createElement("button")
      resizer.type = "button"
      resizer.className = "portal-table-column-resizer"
      resizer.setAttribute("aria-label", `${columnIndex + 1}列目の幅を調整`)
      cell.appendChild(resizer)

      let dragging = false
      let startX = 0
      let startWidth = 0
      const stopDragging = () => {
        dragging = false
        wrapper.classList.remove("is-column-resizing")
        resizer.classList.remove("is-resizing")
      }
      const resizeColumn = (clientX) => {
        widths[columnIndex] = clampColumnWidth(startWidth + clientX - startX)
        applyColumnWidths(table, colgroup, widths)
        writeTableColumnWidths(frame, tableIndex, widths)
      }

      resizer.addEventListener("pointerdown", (event) => {
        dragging = true
        startX = event.clientX
        startWidth = colgroup.children[columnIndex]?.getBoundingClientRect().width || cell.getBoundingClientRect().width
        wrapper.classList.add("is-column-resizing")
        resizer.classList.add("is-resizing")
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
        writeTableColumnWidths(frame, tableIndex, widths)
      })
    })
  }
}
