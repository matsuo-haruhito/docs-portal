const TABLE_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableWidth"
const TABLE_COLUMN_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableColumnWidths"
const TABLE_STICKY_HEADER_STORAGE_PREFIX = "docsPortal.previewTableStickyHeader"
const TABLE_STICKY_COLUMN_STORAGE_PREFIX = "docsPortal.previewTableStickyColumn"
const TABLE_PREFERENCE_COLLECTION_PATH = "/rails_table_preferences/preferences"

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
    .portal-table-preference-panel {
      width: 100%;
      margin-top: .2rem;
      border: 1px solid var(--doc-border-soft, #eef2f7);
      border-radius: 12px;
      background: rgb(255 255 255 / 88%);
      overflow: hidden;
    }
    .portal-table-preference-panel > summary {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: .5rem;
      padding: .35rem .55rem;
      cursor: pointer;
      list-style: none;
      color: var(--doc-text-soft, #334155);
      font-size: .8rem;
      font-weight: 700;
    }
    .portal-table-preference-panel > summary::-webkit-details-marker {
      display: none;
    }
    .portal-table-preference-panel > summary::after {
      content: "▼";
      color: var(--doc-primary, #2563eb);
      font-size: .8rem;
    }
    .portal-table-preference-panel[open] > summary::after {
      content: "▲";
    }
    .portal-table-preference-panel__body {
      display: grid;
      gap: .5rem;
      padding: 0 .55rem .55rem;
    }
    .portal-table-preference-panel__rows {
      display: grid;
      gap: .35rem;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    }
    .portal-table-preference-panel__row {
      display: flex;
      align-items: center;
      gap: .45rem;
      min-height: 2rem;
      padding: .35rem .45rem;
      border: 1px solid var(--doc-border-soft, #eef2f7);
      border-radius: 10px;
      background: var(--doc-surface, #fff);
      color: var(--doc-text-soft, #334155);
      font-size: .78rem;
    }
    .portal-table-preference-panel__row input[type="checkbox"] {
      margin: 0;
      accent-color: var(--doc-primary, #2563eb);
    }
    .portal-table-preference-panel__actions {
      display: flex;
      gap: .35rem;
      align-items: center;
      flex-wrap: wrap;
    }
    .portal-table-preference-status {
      color: var(--doc-text-muted, #64748b);
      font-size: .75rem;
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
      .portal-table-preference-panel__rows {
        grid-template-columns: 1fr;
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
