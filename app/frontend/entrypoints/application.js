import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { RailsTablePreferencesController } from "rails_table_preferences"
import { TomSelectController } from "rails_fields_kit"
import "tom-select/dist/css/tom-select.css"
import { setupTomSelectFields } from "../lib/tom_select_fields"
import { setupMarkdownPreviewTableTools } from "../lib/markdown_preview_table_tools"
import { setupMarkdownPreviewCodeblockTools } from "../lib/markdown_preview_codeblock_tools"
import { setupMarkdownPreviewDocumentSearch } from "../lib/markdown_preview_document_search"
import { setupDocumentFileListSearch } from "../lib/document_file_list_search"
import { setupCsvPreviewTableTools } from "../lib/csv_preview_table_tools"
import { setupStructuredPreviewTools } from "../lib/structured_preview_tools"
import { setupArchivePreviewTools } from "../lib/archive_preview_tools"
import { setupImagePreviewTools } from "../lib/image_preview_tools"
import { setupPdfPreviewTools } from "../lib/pdf_preview_tools"

const application = Application.start()
application.register("rails-table-preferences", RailsTablePreferencesController)
application.register("rails-fields-kit--tom-select", TomSelectController)

const STORAGE_KEY = "docsPortal.sidebar"
const DEFAULT_WIDTH = 360
const MIN_WIDTH = 260
const MAX_WIDTH = 720
const TABLE_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableWidth"
const TABLE_COLUMN_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableColumnWidths"
const TABLE_STICKY_HEADER_STORAGE_PREFIX = "docsPortal.previewTableStickyHeader"
const TABLE_STICKY_COLUMN_STORAGE_PREFIX = "docsPortal.previewTableStickyColumn"
const MIN_COLUMN_WIDTH = 72
const MAX_COLUMN_WIDTH = 960

function clampWidth(value) {
  return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, value))
}

function clampColumnWidth(value) {
  return Math.min(MAX_COLUMN_WIDTH, Math.max(MIN_COLUMN_WIDTH, value))
}

function readState() {
  try {
    return JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "{}")
  } catch (_error) {
    return {}
  }
}

function writeState(nextState) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...readState(), ...nextState }))
}

function applyCollapsedState(layout, toggle, collapsed) {
  layout.classList.toggle("is-sidebar-collapsed", collapsed)
  toggle.setAttribute("aria-expanded", String(!collapsed))
  toggle.setAttribute("aria-label", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
  toggle.setAttribute("title", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
  toggle.textContent = collapsed ? "▶" : "◀"
}

function setupSidebar(layout) {
  if (layout.dataset.sidebarReady === "true") return
  layout.dataset.sidebarReady = "true"

  const sidebar = layout.querySelector("[data-docs-sidebar]")
  const toggle = layout.querySelector("[data-sidebar-toggle]")
  const resizer = layout.querySelector("[data-sidebar-resizer]")
  if (!sidebar || !toggle || !resizer) return

  const storedState = readState()
  const initialWidth = clampWidth(Number(storedState.width) || DEFAULT_WIDTH)
  layout.style.setProperty("--sidebar-width", `${initialWidth}px`)
  applyCollapsedState(layout, toggle, storedState.collapsed === true)

  toggle.addEventListener("click", () => {
    const collapsed = !layout.classList.contains("is-sidebar-collapsed")
    applyCollapsedState(layout, toggle, collapsed)
    writeState({ collapsed })
  })

  let dragging = false
  let startX = 0
  let startWidth = initialWidth

  const stopDragging = () => {
    if (!dragging) return
    dragging = false
    document.body.classList.remove("is-sidebar-resizing")
    sidebar.classList.remove("is-resizing")
  }

  const resizeTo = (clientX) => {
    const nextWidth = clampWidth(startWidth + clientX - startX)
    layout.style.setProperty("--sidebar-width", `${nextWidth}px`)
    writeState({ width: nextWidth, collapsed: false })
  }

  resizer.addEventListener("pointerdown", (event) => {
    if (layout.classList.contains("is-sidebar-collapsed")) return
    dragging = true
    startX = event.clientX
    startWidth = sidebar.getBoundingClientRect().width
    document.body.classList.add("is-sidebar-resizing")
    sidebar.classList.add("is-resizing")
    resizer.setPointerCapture(event.pointerId)
    event.preventDefault()
  })

  resizer.addEventListener("pointermove", (event) => {
    if (!dragging) return
    resizeTo(event.clientX)
  })

  resizer.addEventListener("pointerup", stopDragging)
  resizer.addEventListener("pointercancel", stopDragging)

  resizer.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const currentWidth = sidebar.getBoundingClientRect().width
    const step = event.shiftKey ? 40 : 16
    const nextWidth = event.key === "Home" ? MIN_WIDTH :
      event.key === "End" ? MAX_WIDTH :
      event.key === "ArrowLeft" ? currentWidth - step : currentWidth + step
    const width = clampWidth(nextWidth)
    layout.classList.remove("is-sidebar-collapsed")
    applyCollapsedState(layout, toggle, false)
    layout.style.setProperty("--sidebar-width", `${width}px`)
    writeState({ width, collapsed: false })
  })
}

function setupSidebars() {
  document.querySelectorAll("[data-sidebar-layout]").forEach(setupSidebar)
}

function closeOtherNavDropdowns(currentDropdown) {
  document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
    if (dropdown !== currentDropdown) dropdown.open = false
  })
}

function setupNavDropdowns() {
  if (document.documentElement.dataset.navDropdownsReady === "true") return
  document.documentElement.dataset.navDropdownsReady = "true"

  document.addEventListener("toggle", (event) => {
    const dropdown = event.target.closest?.("[data-nav-dropdown]")
    if (!dropdown || !dropdown.open) return
    closeOtherNavDropdowns(dropdown)
  }, true)

  document.addEventListener("click", (event) => {
    const clickedDropdown = event.target.closest("[data-nav-dropdown]")
    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      if (dropdown !== clickedDropdown) dropdown.open = false
    })
  })

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return
    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      dropdown.open = false
    })
  })
}

function refreshDocumentTree(link) {
  const url = link.dataset.treeRefreshUrl
  if (!url) return

  fetch(url, {
    headers: {
      Accept: "text/vnd.turbo-stream.html"
    },
    credentials: "same-origin"
  })
    .then((response) => response.ok ? response.text() : "")
    .then((html) => {
      if (!html) return
      window.Turbo?.renderStreamMessage(html)
    })
}

function setupDocumentTreeNavigation() {
  document.addEventListener("click", (event) => {
    if (event.target.closest(".tree-toggle")) return

    const link = event.target.closest("a[data-tree-refresh-url]")
    if (!link) return
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return

    refreshDocumentTree(link)
  }, true)
}

function tableWidthStorageKey(frame, index) {
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${TABLE_WIDTH_STORAGE_PREFIX}:${url}:table:${index}`
}

function tableColumnWidthStorageKey(frame, index) {
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${TABLE_COLUMN_WIDTH_STORAGE_PREFIX}:${url}:table:${index}`
}

function tableStickyHeaderStorageKey(frame, index) {
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${TABLE_STICKY_HEADER_STORAGE_PREFIX}:${url}:table:${index}`
}

function tableStickyColumnStorageKey(frame, index) {
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${TABLE_STICKY_COLUMN_STORAGE_PREFIX}:${url}:table:${index}`
}

function readTableWidth(frame, index) {
  const value = Number(window.localStorage.getItem(tableWidthStorageKey(frame, index)))
  return Number.isFinite(value) && value >= 80 && value <= 220 ? value : 100
}

function writeTableWidth(frame, index, value) {
  window.localStorage.setItem(tableWidthStorageKey(frame, index), String(value))
}

function readTableColumnWidths(frame, index) {
  try {
    const values = JSON.parse(window.localStorage.getItem(tableColumnWidthStorageKey(frame, index)) || "[]")
    return Array.isArray(values) ? values.map((value) => Number(value)).filter(Number.isFinite) : []
  } catch (_error) {
    return []
  }
}

function writeTableColumnWidths(frame, index, widths) {
  window.localStorage.setItem(tableColumnWidthStorageKey(frame, index), JSON.stringify(widths))
}

function readStickyHeader(frame, index) {
  return window.localStorage.getItem(tableStickyHeaderStorageKey(frame, index)) === "true"
}

function writeStickyHeader(frame, index, enabled) {
  window.localStorage.setItem(tableStickyHeaderStorageKey(frame, index), String(enabled))
}

function readStickyColumn(frame, index) {
  return window.localStorage.getItem(tableStickyColumnStorageKey(frame, index)) === "true"
}

function writeStickyColumn(frame, index, enabled) {
  window.localStorage.setItem(tableStickyColumnStorageKey(frame, index), String(enabled))
}

function resetTableColumnWidths(frame, index, table) {
  window.localStorage.removeItem(tableColumnWidthStorageKey(frame, index))
  const colgroup = table.querySelector("colgroup[data-docs-portal-column-widths]")
  colgroup?.remove()
  table.style.tableLayout = ""
}

function applyStickyHeader(wrapper, button, enabled) {
  wrapper.classList.toggle("has-sticky-header", enabled)
  button.textContent = enabled ? "ヘッダー固定中" : "ヘッダー固定"
  button.setAttribute("aria-pressed", String(enabled))
}

function applyStickyColumn(wrapper, button, enabled) {
  wrapper.classList.toggle("has-sticky-column", enabled)
  button.textContent = enabled ? "先頭列固定中" : "先頭列固定"
  button.setAttribute("aria-pressed", String(enabled))
}

function injectTableWidthStyle(frameDocument) {
  if (frameDocument.querySelector("style[data-docs-portal-table-width]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalTableWidth = "true"
  style.textContent = `
    .portal-table-width-frame {
      margin: 1rem 0;
      border: 1px solid var(--doc-border, #e5e7eb);
      border-radius: 12px;
      background: var(--doc-surface, #fff);
      overflow: hidden;
    }
    .portal-table-width-toolbar {
      display: flex;
      gap: .55rem;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      padding: .55rem .75rem;
      border-bottom: 1px solid var(--doc-border-soft, #eef2f7);
      background: var(--doc-bg-soft, #f8fafc);
      color: var(--doc-text-muted, #64748b);
      font-size: .82rem;
    }
    .portal-table-width-toolbar label {
      display: inline-flex;
      gap: .45rem;
      align-items: center;
      margin: 0;
      white-space: nowrap;
    }
    .portal-table-width-toolbar input[type="range"] {
      width: 160px;
      accent-color: var(--doc-primary, #2563eb);
    }
    .portal-table-width-actions {
      display: inline-flex;
      gap: .35rem;
      align-items: center;
      flex-wrap: wrap;
    }
    .portal-table-width-button {
      border: 1px solid var(--doc-primary-border, #bfdbfe);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: var(--doc-primary, #2563eb);
      cursor: pointer;
      font: inherit;
      font-size: .78rem;
      padding: .24rem .58rem;
    }
    .portal-table-width-button:hover,
    .portal-table-width-button:focus,
    .portal-table-width-button[aria-pressed="true"] {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
    }
    .portal-table-width-button[aria-pressed="true"] {
      background: var(--doc-primary, #2563eb);
      color: #fff;
    }
    .portal-table-width-hint {
      color: var(--doc-text-muted, #64748b);
      font-size: .78rem;
    }
    .portal-table-width-scroll {
      overflow: auto;
      max-height: min(70vh, 720px);
      padding: .65rem;
    }
    .portal-table-width-frame table {
      margin: 0 !important;
      width: var(--portal-table-width, 100%) !important;
      min-width: var(--portal-table-width, 100%) !important;
      max-width: none !important;
      display: table !important;
    }
    .portal-table-width-frame th,
    .portal-table-width-frame td {
      position: relative;
    }
    .portal-table-width-frame.has-sticky-header thead th,
    .portal-table-width-frame.has-sticky-header tr:first-child th {
      position: sticky;
      top: 0;
      z-index: 4;
      background: var(--doc-bg-soft, #f8fafc);
      box-shadow: 0 1px 0 var(--doc-border, #e5e7eb);
    }
    .portal-table-width-frame.has-sticky-header tr:first-child td {
      position: sticky;
      top: 0;
      z-index: 3;
      background: var(--doc-bg-soft, #f8fafc);
      box-shadow: 0 1px 0 var(--doc-border, #e5e7eb);
    }
    .portal-table-width-frame.has-sticky-column tr > :first-child {
      position: sticky;
      left: 0;
      z-index: 2;
      background: var(--doc-surface, #fff);
      box-shadow: 1px 0 0 var(--doc-border, #e5e7eb);
    }
    .portal-table-width-frame.has-sticky-header.has-sticky-column thead tr > :first-child,
    .portal-table-width-frame.has-sticky-header.has-sticky-column tr:first-child > :first-child {
      z-index: 6;
      background: var(--doc-bg-soft, #f8fafc);
    }
    .portal-table-column-resizer {
      position: absolute;
      top: 0;
      right: -4px;
      z-index: 7;
      width: 8px;
      height: 100%;
      min-height: 28px;
      padding: 0;
      border: 0;
      border-radius: 0;
      background: transparent;
      box-shadow: none;
      cursor: col-resize;
    }
    .portal-table-column-resizer::after {
      content: "";
      position: absolute;
      top: 7px;
      bottom: 7px;
      left: 3px;
      width: 2px;
      border-radius: 999px;
      background: transparent;
    }
    .portal-table-column-resizer:hover::after,
    .portal-table-column-resizer:focus::after,
    .portal-table-column-resizer.is-resizing::after {
      background: var(--doc-primary, #2563eb);
      box-shadow: 0 0 0 3px rgb(37 99 235 / 14%);
    }
    .portal-table-width-frame.is-column-resizing,
    .portal-table-width-frame.is-column-resizing * {
      cursor: col-resize !important;
      user-select: none;
    }
    @media (max-width: 720px) {
      .portal-table-width-toolbar {
        align-items: flex-start;
        flex-direction: column;
      }
      .portal-table-width-toolbar input[type="range"] {
        width: 190px;
      }
    }
  `
  frameDocument.head?.appendChild(style)
}

function tableColumnCount(table) {
  return Math.max(...Array.from(table.rows).map((row) => row.cells.length), 0)
}

function ensureTableColgroup(frameDocument, table, columnCount) {
  let colgroup = table.querySelector("colgroup[data-docs-portal-column-widths]")
  if (!colgroup) {
    colgroup = frameDocument.createElement("colgroup")
    colgroup.dataset.docsPortalColumnWidths = "true"
    table.prepend(colgroup)
  }

  while (colgroup.children.length < columnCount) {
    colgroup.appendChild(frameDocument.createElement("col"))
  }
  while (colgroup.children.length > columnCount) {
    colgroup.lastElementChild?.remove()
  }

  return colgroup
}

function applyTableColumnWidths(table, colgroup, widths) {
  table.style.tableLayout = widths.some((width) => Number.isFinite(width)) ? "fixed" : ""
  Array.from(colgroup.children).forEach((col, columnIndex) => {
    const width = widths[columnIndex]
    if (Number.isFinite(width)) {
      col.style.width = `${clampColumnWidth(width)}px`
    } else {
      col.style.width = ""
    }
  })
}

function setupColumnResizers(frame, table, tableIndex, wrapper) {
  const frameDocument = frame.contentDocument
  const columnCount = tableColumnCount(table)
  if (!frameDocument || columnCount <= 1) return

  const colgroup = ensureTableColgroup(frameDocument, table, columnCount)
  const widths = readTableColumnWidths(frame, tableIndex)
  applyTableColumnWidths(table, colgroup, widths)

  const headerRow = table.tHead?.rows?.[0] || table.rows[0]
  if (!headerRow) return

  Array.from(headerRow.cells).forEach((cell, columnIndex) => {
    if (columnIndex >= columnCount - 1) return
    if (cell.querySelector(".portal-table-column-resizer")) return

    const resizer = frameDocument.createElement("button")
    resizer.type = "button"
    resizer.className = "portal-table-column-resizer"
    resizer.setAttribute("aria-label", `${columnIndex + 1}列目の幅を調整`)
    cell.appendChild(resizer)

    let dragging = false
    let startX = 0
    let startWidth = 0

    const stopDragging = () => {
      if (!dragging) return
      dragging = false
      wrapper.classList.remove("is-column-resizing")
      resizer.classList.remove("is-resizing")
    }

    const resizeColumn = (clientX) => {
      const nextWidth = clampColumnWidth(startWidth + clientX - startX)
      widths[columnIndex] = nextWidth
      applyTableColumnWidths(table, colgroup, widths)
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
      if (!dragging) return
      resizeColumn(event.clientX)
    })

    resizer.addEventListener("pointerup", stopDragging)
    resizer.addEventListener("pointercancel", stopDragging)

    resizer.addEventListener("keydown", (event) => {
      if (!["ArrowLeft", "ArrowRight", "Home"].includes(event.key)) return
      event.preventDefault()
      const currentWidth = colgroup.children[columnIndex]?.getBoundingClientRect().width || cell.getBoundingClientRect().width
      const step = event.shiftKey ? 40 : 16
      const nextWidth = event.key === "Home" ? MIN_COLUMN_WIDTH :
        event.key === "ArrowLeft" ? currentWidth - step : currentWidth + step
      widths[columnIndex] = clampColumnWidth(nextWidth)
      applyTableColumnWidths(table, colgroup, widths)
      writeTableColumnWidths(frame, tableIndex, widths)
    })
  })
}

function enhancePreviewTables(frame) {
  const frameDocument = frame.contentDocument
  if (!frameDocument?.body) return

  injectTableWidthStyle(frameDocument)

  const tables = Array.from(frameDocument.querySelectorAll(".markdown table, .theme-doc-markdown table, article table"))
    .filter((table) => !table.closest(".portal-table-width-frame"))

  tables.forEach((table, index) => {
    const width = readTableWidth(frame, index)
    const stickyHeader = readStickyHeader(frame, index)
    const stickyColumn = readStickyColumn(frame, index)
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

    const fitButton = frameDocument.createElement("button")
    fitButton.type = "button"
    fitButton.className = "portal-table-width-button"
    fitButton.textContent = "標準"

    const wideButton = frameDocument.createElement("button")
    wideButton.type = "button"
    wideButton.className = "portal-table-width-button"
    wideButton.textContent = "広め"

    const stickyHeaderButton = frameDocument.createElement("button")
    stickyHeaderButton.type = "button"
    stickyHeaderButton.className = "portal-table-width-button"

    const stickyColumnButton = frameDocument.createElement("button")
    stickyColumnButton.type = "button"
    stickyColumnButton.className = "portal-table-width-button"

    const resetColumnsButton = frameDocument.createElement("button")
    resetColumnsButton.type = "button"
    resetColumnsButton.className = "portal-table-width-button"
    resetColumnsButton.textContent = "列幅リセット"

    const hint = frameDocument.createElement("span")
    hint.className = "portal-table-width-hint"
    hint.textContent = "列境界をドラッグできます"

    actions.appendChild(fitButton)
    actions.appendChild(wideButton)
    actions.appendChild(stickyHeaderButton)
    actions.appendChild(stickyColumnButton)
    actions.appendChild(resetColumnsButton)
    actions.appendChild(hint)
    toolbar.appendChild(label)
    toolbar.appendChild(actions)

    const scroll = frameDocument.createElement("div")
    scroll.className = "portal-table-width-scroll"

    table.parentNode.insertBefore(wrapper, table)
    scroll.appendChild(table)
    wrapper.appendChild(toolbar)
    wrapper.appendChild(scroll)
    applyStickyHeader(wrapper, stickyHeaderButton, stickyHeader)
    applyStickyColumn(wrapper, stickyColumnButton, stickyColumn)

    const applyWidth = (nextWidth) => {
      wrapper.style.setProperty("--portal-table-width", `${nextWidth}%`)
      range.value = String(nextWidth)
      valueText.textContent = `${nextWidth}%`
      writeTableWidth(frame, index, nextWidth)
    }

    range.addEventListener("input", () => applyWidth(Number(range.value)))
    fitButton.addEventListener("click", () => applyWidth(100))
    wideButton.addEventListener("click", () => applyWidth(160))
    stickyHeaderButton.addEventListener("click", () => {
      const enabled = !wrapper.classList.contains("has-sticky-header")
      applyStickyHeader(wrapper, stickyHeaderButton, enabled)
      writeStickyHeader(frame, index, enabled)
    })
    stickyColumnButton.addEventListener("click", () => {
      const enabled = !wrapper.classList.contains("has-sticky-column")
      applyStickyColumn(wrapper, stickyColumnButton, enabled)
      writeStickyColumn(frame, index, enabled)
    })
    resetColumnsButton.addEventListener("click", () => resetTableColumnWidths(frame, index, table))

    setupColumnResizers(frame, table, index, wrapper)
  })
}

function setupPreviewTableResizers() {
  document.querySelectorAll("iframe.site-viewer-frame").forEach((frame) => {
    if (frame.dataset.tableWidthReady === "true") return
    frame.dataset.tableWidthReady = "true"

    const enhance = () => {
      try {
        enhancePreviewTables(frame)
      } catch (_error) {
        // Cross-origin fallback: if the preview ever becomes external, keep the viewer usable.
      }
    }

    frame.addEventListener("load", enhance)
    if (frame.contentDocument?.readyState === "complete") enhance()
  })
}

setupNavDropdowns()
setupDocumentTreeNavigation()

document.addEventListener("turbo:load", () => {
  setupSidebars()
  setupPreviewTableResizers()
  setupMarkdownPreviewDocumentSearch()
  setupMarkdownPreviewTableTools()
  setupMarkdownPreviewCodeblockTools()
  setupDocumentFileListSearch()
  setupCsvPreviewTableTools()
  setupStructuredPreviewTools()
  setupArchivePreviewTools()
  setupImagePreviewTools()
  setupPdfPreviewTools()
  setupTomSelectFields()
})
document.addEventListener("turbo:render", () => {
  setupSidebars()
  setupPreviewTableResizers()
  setupMarkdownPreviewDocumentSearch()
  setupMarkdownPreviewTableTools()
  setupMarkdownPreviewCodeblockTools()
  setupDocumentFileListSearch()
  setupCsvPreviewTableTools()
  setupStructuredPreviewTools()
  setupArchivePreviewTools()
  setupImagePreviewTools()
  setupPdfPreviewTools()
  setupTomSelectFields()
})
