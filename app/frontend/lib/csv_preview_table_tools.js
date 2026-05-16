const MIN_COLUMN_WIDTH = 72
const MAX_COLUMN_WIDTH = 960
const COLUMN_WIDTH_STORAGE_PREFIX = "docsPortal.csvPreviewColumnWidths"
const STICKY_STATE_STORAGE_PREFIX = "docsPortal.csvPreviewStickyState"

function escapeCsvCell(value) {
  const text = (value || "").toString()
  return /[",\n\r]/.test(text) ? `"${text.replaceAll("\"", "\"\"")}"` : text
}

function clampColumnWidth(value) {
  return Math.min(MAX_COLUMN_WIDTH, Math.max(MIN_COLUMN_WIDTH, value))
}

function storageKey(container, prefix) {
  const key = container.dataset.csvPreviewStorageKey || window.location.pathname
  return `${prefix}:${key}`
}

function columnWidthStorageKey(container) {
  return storageKey(container, COLUMN_WIDTH_STORAGE_PREFIX)
}

function stickyStateStorageKey(container) {
  return storageKey(container, STICKY_STATE_STORAGE_PREFIX)
}

function readColumnWidths(container) {
  try {
    const values = JSON.parse(window.localStorage.getItem(columnWidthStorageKey(container)) || "[]")
    return Array.isArray(values) ? values.map((value) => Number(value)).filter(Number.isFinite) : []
  } catch (_error) {
    return []
  }
}

function writeColumnWidths(container, widths) {
  window.localStorage.setItem(columnWidthStorageKey(container), JSON.stringify(widths))
}

function clearColumnWidths(container) {
  window.localStorage.removeItem(columnWidthStorageKey(container))
}

function readStickyState(container) {
  try {
    return { stickyHeader: true, stickyColumn: true, ...JSON.parse(window.localStorage.getItem(stickyStateStorageKey(container)) || "{}") }
  } catch (_error) {
    return { stickyHeader: true, stickyColumn: true }
  }
}

function writeStickyState(container, state) {
  window.localStorage.setItem(stickyStateStorageKey(container), JSON.stringify(state))
}

function injectCsvPreviewStyle() {
  if (document.querySelector("style[data-csv-preview-table-tools]")) return

  const style = document.createElement("style")
  style.dataset.csvPreviewTableTools = "true"
  style.textContent = `
    [data-csv-preview-tools].has-sticky-header [data-csv-preview-table] tbody tr:first-child th,
    [data-csv-preview-tools].has-sticky-header [data-csv-preview-table] tbody tr:first-child td {
      position: sticky;
      top: 0;
      z-index: 3;
      background: var(--doc-bg-soft, #f8fafc);
      box-shadow: 0 1px 0 var(--doc-border, #e5e7eb);
      font-weight: 700;
    }
    [data-csv-preview-tools].has-sticky-header [data-csv-preview-table] tbody tr:first-child th {
      z-index: 5;
    }
    [data-csv-preview-tools].has-sticky-column [data-csv-preview-table] tbody tr > :first-child {
      position: sticky;
      left: 0;
      z-index: 4;
      background: var(--doc-surface, #fff);
      box-shadow: 1px 0 0 var(--doc-border, #e5e7eb);
    }
    [data-csv-preview-tools].has-sticky-header.has-sticky-column [data-csv-preview-table] tbody tr:first-child > :first-child {
      z-index: 6;
      background: var(--doc-bg-soft, #f8fafc);
    }
    [data-csv-preview-table].has-resized-columns {
      table-layout: fixed;
    }
    [data-csv-preview-table] tbody tr:first-child > th,
    [data-csv-preview-table] tbody tr:first-child > td {
      position: relative;
    }
    .csv-preview-column-resizer {
      position: absolute;
      top: 0;
      right: -4px;
      z-index: 8;
      width: 8px;
      height: 100%;
      min-height: 28px;
      padding: 0;
      border: 0;
      background: transparent;
      cursor: col-resize;
    }
    .csv-preview-column-resizer::after {
      content: "";
      position: absolute;
      top: 7px;
      bottom: 7px;
      left: 3px;
      width: 2px;
      border-radius: 999px;
      background: transparent;
    }
    .csv-preview-column-resizer:hover::after,
    .csv-preview-column-resizer:focus::after,
    .csv-preview-column-resizer.is-resizing::after {
      background: var(--doc-primary, #2563eb);
      box-shadow: 0 0 0 3px rgb(37 99 235 / 14%);
    }
    [data-csv-preview-tools].is-column-resizing,
    [data-csv-preview-tools].is-column-resizing * {
      cursor: col-resize !important;
      user-select: none;
    }
  `
  document.head?.appendChild(style)
}

function rowText(row) {
  return Array.from(row.querySelectorAll("th, td"))
    .map((cell) => cell.textContent || "")
    .join(" ")
    .toLowerCase()
}

function tableToCsv(table) {
  return Array.from(table.querySelectorAll("tbody tr:not([hidden])"))
    .map((row) => Array.from(row.querySelectorAll("td"))
      .map((cell) => escapeCsvCell(cell.textContent || ""))
      .join(","))
    .join("\n")
}

function tableColumnCount(table) {
  return Math.max(...Array.from(table.rows).map((row) => row.cells.length), 0)
}

function ensureColgroup(table, columnCount) {
  let colgroup = table.querySelector("colgroup[data-csv-preview-column-widths]")
  if (!colgroup) {
    colgroup = document.createElement("colgroup")
    colgroup.dataset.csvPreviewColumnWidths = "true"
    table.prepend(colgroup)
  }

  while (colgroup.children.length < columnCount) colgroup.appendChild(document.createElement("col"))
  while (colgroup.children.length > columnCount) colgroup.lastElementChild?.remove()

  return colgroup
}

function applyColumnWidths(table, colgroup, widths) {
  const hasWidths = widths.some((width) => Number.isFinite(width))
  table.classList.toggle("has-resized-columns", hasWidths)

  Array.from(colgroup.children).forEach((col, columnIndex) => {
    const width = widths[columnIndex]
    col.style.width = Number.isFinite(width) ? `${clampColumnWidth(width)}px` : ""
  })
}

function resetColumnWidths(container, table) {
  table.querySelectorAll("colgroup[data-csv-preview-column-widths] col").forEach((col) => {
    col.style.width = ""
  })
  table.classList.remove("has-resized-columns")
  clearColumnWidths(container)
}

function setupColumnResizers(container, table) {
  const columnCount = tableColumnCount(table)
  if (columnCount <= 1) return

  const colgroup = ensureColgroup(table, columnCount)
  const widths = readColumnWidths(container)
  applyColumnWidths(table, colgroup, widths)

  const headerRow = table.rows[0]
  if (!headerRow) return

  Array.from(headerRow.cells).forEach((cell, columnIndex) => {
    if (columnIndex >= columnCount - 1) return
    if (cell.querySelector(".csv-preview-column-resizer")) return

    const resizer = document.createElement("button")
    resizer.type = "button"
    resizer.className = "csv-preview-column-resizer"
    resizer.setAttribute("aria-label", `${columnIndex + 1}列目の幅を調整`)
    cell.appendChild(resizer)

    let dragging = false
    let startX = 0
    let startWidth = 0

    const applyWidth = (width) => {
      widths[columnIndex] = clampColumnWidth(width)
      applyColumnWidths(table, colgroup, widths)
      writeColumnWidths(container, widths)
    }

    const stopDragging = () => {
      if (!dragging) return
      dragging = false
      container.classList.remove("is-column-resizing")
      resizer.classList.remove("is-resizing")
    }

    const resizeColumn = (clientX) => {
      applyWidth(startWidth + clientX - startX)
    }

    resizer.addEventListener("pointerdown", (event) => {
      dragging = true
      startX = event.clientX
      startWidth = colgroup.children[columnIndex]?.getBoundingClientRect().width || cell.getBoundingClientRect().width
      container.classList.add("is-column-resizing")
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
      applyWidth(nextWidth)
    })
  })
}

function setupCsvPreviewTable(container) {
  if (container.dataset.csvPreviewToolsReady === "true") return
  container.dataset.csvPreviewToolsReady = "true"
  injectCsvPreviewStyle()

  const input = container.querySelector("[data-csv-preview-search-input]")
  const clearButton = container.querySelector("[data-csv-preview-search-clear]")
  const copyButton = container.querySelector("[data-csv-preview-copy]")
  const stickyHeaderButton = container.querySelector("[data-csv-preview-sticky-header]")
  const stickyColumnButton = container.querySelector("[data-csv-preview-sticky-column]")
  const resetColumnsButton = container.querySelector("[data-csv-preview-reset-columns]")
  const count = container.querySelector("[data-csv-preview-count]")
  const status = container.querySelector("[data-csv-preview-status]")
  const table = container.querySelector("[data-csv-preview-table]")
  if (!input || !clearButton || !copyButton || !stickyHeaderButton || !stickyColumnButton || !resetColumnsButton || !count || !status || !table) return

  const rows = Array.from(table.querySelectorAll("tbody tr"))
  const stickyState = readStickyState(container)

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    let visibleCount = 0

    rows.forEach((row) => {
      const matched = query.length === 0 || rowText(row).includes(query)
      row.hidden = !matched
      row.classList.toggle("is-document-file-search-match", query.length > 0 && matched)
      if (matched) visibleCount += 1
    })

    count.textContent = query.length === 0 ? `${rows.length}行` : `${visibleCount}/${rows.length}行`
  }

  const updateStickyHeader = (enabled) => {
    stickyState.stickyHeader = enabled
    container.classList.toggle("has-sticky-header", enabled)
    stickyHeaderButton.setAttribute("aria-pressed", String(enabled))
    stickyHeaderButton.textContent = enabled ? "先頭行固定中" : "先頭行固定"
    writeStickyState(container, stickyState)
  }

  const updateStickyColumn = (enabled) => {
    stickyState.stickyColumn = enabled
    container.classList.toggle("has-sticky-column", enabled)
    stickyColumnButton.setAttribute("aria-pressed", String(enabled))
    stickyColumnButton.textContent = enabled ? "先頭列固定中" : "先頭列固定"
    writeStickyState(container, stickyState)
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  clearButton.addEventListener("click", () => {
    input.value = ""
    updateSearch()
    input.focus()
  })

  copyButton.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(tableToCsv(table))
      status.textContent = "コピーしました"
    } catch (_error) {
      status.textContent = "コピーできませんでした"
    }

    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
  })

  stickyHeaderButton.addEventListener("click", () => {
    updateStickyHeader(!container.classList.contains("has-sticky-header"))
  })

  stickyColumnButton.addEventListener("click", () => {
    updateStickyColumn(!container.classList.contains("has-sticky-column"))
  })

  resetColumnsButton.addEventListener("click", () => {
    resetColumnWidths(container, table)
    status.textContent = "列幅をリセットしました"
    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
  })

  setupColumnResizers(container, table)
  updateSearch()
  updateStickyHeader(stickyState.stickyHeader)
  updateStickyColumn(stickyState.stickyColumn)
}

export function setupCsvPreviewTableTools() {
  document.querySelectorAll("[data-csv-preview-tools]").forEach(setupCsvPreviewTable)
}
