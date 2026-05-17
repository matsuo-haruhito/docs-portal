const TABLE_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableWidth"
const TABLE_COLUMN_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableColumnWidths"
const TABLE_STICKY_HEADER_STORAGE_PREFIX = "docsPortal.previewTableStickyHeader"
const TABLE_STICKY_COLUMN_STORAGE_PREFIX = "docsPortal.previewTableStickyColumn"

function injectTableSearchStyle(frameDocument) {
  if (frameDocument.querySelector("style[data-docs-portal-table-search]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalTableSearch = "true"
  style.textContent = `
    .portal-table-utility-bar {
      display: flex;
      gap: .45rem;
      align-items: center;
      flex-wrap: wrap;
      width: 100%;
    }
    .portal-table-toolbar-group {
      display: inline-flex;
      gap: .35rem;
      align-items: center;
      flex-wrap: wrap;
      padding: .2rem .35rem;
      border: 1px solid var(--doc-border-soft, #eef2f7);
      border-radius: 999px;
      background: rgb(255 255 255 / 82%);
    }
    .portal-table-toolbar-label {
      color: var(--doc-text-muted, #64748b);
      font-size: .72rem;
      font-weight: 700;
      letter-spacing: .02em;
      white-space: nowrap;
    }
    .portal-table-search {
      display: inline-flex;
      gap: .35rem;
      align-items: center;
      flex-wrap: wrap;
    }
    .portal-table-search input[type="search"] {
      width: 180px;
      border: 1px solid var(--doc-border, #dbe3ef);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: inherit;
      font: inherit;
      font-size: .78rem;
      padding: .25rem .65rem;
    }
    .portal-table-search input[type="search"]:focus {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
      box-shadow: 0 0 0 3px rgb(37 99 235 / 14%);
    }
    .portal-table-search-count {
      min-width: 2.5rem;
      color: var(--doc-text-muted, #64748b);
      font-size: .78rem;
    }
    .portal-table-search-hidden {
      display: none !important;
    }
    .portal-table-search-match {
      background: #fff7cc !important;
      outline: 2px solid #f59e0b;
      outline-offset: -2px;
    }
    @media (max-width: 720px) {
      .portal-table-utility-bar,
      .portal-table-toolbar-group {
        align-items: flex-start;
        border-radius: 12px;
        flex-direction: column;
      }
      .portal-table-search input[type="search"] {
        width: 190px;
      }
    }
  `
  frameDocument.head?.appendChild(style)
}

function tableSettingKey(prefix, frame, index) {
  const wrapper = frame.contentDocument?.querySelector(`.portal-table-width-frame[data-docs-portal-table-index="${index}"]`)
  const stableIndex = wrapper?.dataset.docsPortalTableIndex || String(index)
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${prefix}:${url}:table:${stableIndex}`
}

function tableIndex(wrapper, fallbackIndex) {
  const index = Number(wrapper.dataset.docsPortalTableIndex)
  return Number.isInteger(index) && index >= 0 ? index : fallbackIndex
}

function clearTableSettings(frame, index) {
  window.localStorage.removeItem(tableSettingKey(TABLE_WIDTH_STORAGE_PREFIX, frame, index))
  window.localStorage.removeItem(tableSettingKey(TABLE_COLUMN_WIDTH_STORAGE_PREFIX, frame, index))
  window.localStorage.removeItem(tableSettingKey(TABLE_STICKY_HEADER_STORAGE_PREFIX, frame, index))
  window.localStorage.removeItem(tableSettingKey(TABLE_STICKY_COLUMN_STORAGE_PREFIX, frame, index))
}

function setPressedButton(button, text, pressed) {
  if (!button) return
  button.textContent = text
  button.setAttribute("aria-pressed", String(pressed))
}

function resetTableDisplaySettings(frame, index, wrapper, table, status) {
  clearTableSettings(frame, index)

  wrapper.style.setProperty("--portal-table-width", "100%")
  wrapper.classList.remove("has-sticky-header", "has-sticky-column")
  table.style.tableLayout = ""
  table.querySelector("colgroup[data-docs-portal-column-widths]")?.remove()

  const widthRange = wrapper.querySelector(".portal-table-width-toolbar input[type='range']")
  if (widthRange) {
    widthRange.value = "100"
    const valueText = widthRange.nextElementSibling
    if (valueText) valueText.textContent = "100%"
  }

  const toolbarButtons = Array.from(wrapper.querySelectorAll(".portal-table-width-button"))
  setPressedButton(toolbarButtons.find((button) => button.textContent.includes("ヘッダー固定")), "ヘッダー固定", false)
  setPressedButton(toolbarButtons.find((button) => button.textContent.includes("先頭列固定")), "先頭列固定", false)

  status.textContent = "表示設定をリセットしました"
  window.setTimeout(() => {
    status.textContent = ""
  }, 1800)
}

function updateTableSearch(table, input, count) {
  const query = input.value.trim().toLowerCase()
  let matchCount = 0
  Array.from(table.rows).forEach((row, rowIndex) => {
    const cells = Array.from(row.cells)
    let rowMatched = false

    cells.forEach((cell) => {
      const matched = query.length > 0 && cell.textContent.toLowerCase().includes(query)
      cell.classList.toggle("portal-table-search-match", matched)
      if (matched) {
        matchCount += 1
        rowMatched = true
      }
    })

    const isHeaderRow = row.closest("thead") || rowIndex === 0
    row.classList.toggle("portal-table-search-hidden", query.length > 0 && !rowMatched && !isHeaderRow)
  })

  count.textContent = query.length > 0 ? `${matchCount}件` : ""
}

function tableRows(table) {
  return Array.from(table.rows).map((row) => Array.from(row.cells).map((cell) => cell.textContent.trim().replace(/\s+/g, " ")))
}

function csvEscape(value) {
  const text = String(value ?? "")
  if (/[",\n\r]/.test(text)) return `"${text.replaceAll('"', '""')}"`
  return text
}

function tableToCsv(table) {
  return tableRows(table).map((row) => row.map(csvEscape).join(",")).join("\n")
}

function markdownEscape(value) {
  return String(value ?? "").replaceAll("|", "\\|").replace(/\s+/g, " ").trim()
}

function tableToMarkdown(table) {
  const rows = tableRows(table)
  if (rows.length === 0) return ""

  const columnCount = Math.max(...rows.map((row) => row.length), 0)
  const normalizedRows = rows.map((row) => Array.from({ length: columnCount }, (_, index) => markdownEscape(row[index] || "")))
  const header = normalizedRows[0]
  const separator = Array.from({ length: columnCount }, () => "---")
  const body = normalizedRows.slice(1)

  return [header, separator, ...body].map((row) => `| ${row.join(" | ")} |`).join("\n")
}

async function copyText(text, status) {
  try {
    await navigator.clipboard.writeText(text)
    status.textContent = "コピーしました"
  } catch (_error) {
    status.textContent = "コピーできませんでした"
  }

  window.setTimeout(() => {
    status.textContent = ""
  }, 1800)
}

function createToolbarGroup(frameDocument, labelText) {
  const group = frameDocument.createElement("span")
  group.className = "portal-table-toolbar-group"

  const label = frameDocument.createElement("span")
  label.className = "portal-table-toolbar-label"
  label.textContent = labelText
  group.appendChild(label)

  return group
}

function toolbarInsertionTarget(toolbar) {
  return toolbar.querySelector(".portal-table-width-toolbar-body") || toolbar
}

function enhanceTablesInFrame(frame) {
  const frameDocument = frame.contentDocument
  if (!frameDocument?.body) return

  injectTableSearchStyle(frameDocument)

  frameDocument.querySelectorAll(".portal-table-width-frame").forEach((wrapper, fallbackIndex) => {
    if (wrapper.dataset.tableSearchReady === "true") return
    const table = wrapper.querySelector("table")
    const toolbar = wrapper.querySelector(".portal-table-width-toolbar")
    if (!table || !toolbar) return

    wrapper.dataset.tableSearchReady = "true"
    const index = tableIndex(wrapper, fallbackIndex)

    const utilityBar = frameDocument.createElement("div")
    utilityBar.className = "portal-table-utility-bar"

    const searchGroup = createToolbarGroup(frameDocument, "検索")
    const displayGroup = createToolbarGroup(frameDocument, "表示")
    const copyGroup = createToolbarGroup(frameDocument, "コピー")

    const search = frameDocument.createElement("label")
    search.className = "portal-table-search"

    const input = frameDocument.createElement("input")
    input.type = "search"
    input.placeholder = "キーワード"
    input.setAttribute("aria-label", "表内を検索")

    const count = frameDocument.createElement("span")
    count.className = "portal-table-search-count"
    count.setAttribute("aria-live", "polite")

    const clearButton = frameDocument.createElement("button")
    clearButton.type = "button"
    clearButton.className = "portal-table-width-button"
    clearButton.textContent = "クリア"

    const resetSettingsButton = frameDocument.createElement("button")
    resetSettingsButton.type = "button"
    resetSettingsButton.className = "portal-table-width-button"
    resetSettingsButton.textContent = "表示リセット"

    const copyCsvButton = frameDocument.createElement("button")
    copyCsvButton.type = "button"
    copyCsvButton.className = "portal-table-width-button"
    copyCsvButton.textContent = "CSV"

    const copyMarkdownButton = frameDocument.createElement("button")
    copyMarkdownButton.type = "button"
    copyMarkdownButton.className = "portal-table-width-button"
    copyMarkdownButton.textContent = "Markdown"

    const copyStatus = frameDocument.createElement("span")
    copyStatus.className = "portal-table-search-count"
    copyStatus.setAttribute("aria-live", "polite")

    search.appendChild(input)
    search.appendChild(count)
    searchGroup.appendChild(search)
    searchGroup.appendChild(clearButton)
    displayGroup.appendChild(resetSettingsButton)
    copyGroup.appendChild(copyCsvButton)
    copyGroup.appendChild(copyMarkdownButton)
    copyGroup.appendChild(copyStatus)

    utilityBar.appendChild(searchGroup)
    utilityBar.appendChild(displayGroup)
    utilityBar.appendChild(copyGroup)

    const target = toolbarInsertionTarget(toolbar)
    target.insertBefore(utilityBar, target.firstChild)

    input.addEventListener("input", () => updateTableSearch(table, input, count))
    clearButton.addEventListener("click", () => {
      input.value = ""
      updateTableSearch(table, input, count)
      input.focus()
    })
    resetSettingsButton.addEventListener("click", () => resetTableDisplaySettings(frame, index, wrapper, table, copyStatus))
    copyCsvButton.addEventListener("click", () => copyText(tableToCsv(table), copyStatus))
    copyMarkdownButton.addEventListener("click", () => copyText(tableToMarkdown(table), copyStatus))
  })
}

export function setupMarkdownPreviewTableTools() {
  document.querySelectorAll("iframe.site-viewer-frame").forEach((frame) => {
    if (frame.dataset.tableSearchListenerReady !== "true") {
      frame.dataset.tableSearchListenerReady = "true"
      frame.addEventListener("load", () => {
        try {
          enhanceTablesInFrame(frame)
        } catch (_error) {
          // Cross-origin fallback: keep the viewer usable even if table tools cannot be injected.
        }
      })
      frame.addEventListener("docs-portal:preview-tables-enhanced", () => {
        try {
          enhanceTablesInFrame(frame)
        } catch (_error) {
          // Cross-origin fallback: keep the viewer usable even if table tools cannot be injected.
        }
      })
    }

    try {
      enhanceTablesInFrame(frame)
    } catch (_error) {
      // Cross-origin fallback: keep the viewer usable even if table tools cannot be injected.
    }
  })
}