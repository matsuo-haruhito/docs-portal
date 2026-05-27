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

function cgiEscape(value) {
  return encodeURIComponent(String(value ?? ""))
    .replace(/%20/g, "+")
    .replace(/\./g, "%2E")
}

function stableTablePreferenceKeyFromContext(previewContextKey, tableIndexValue) {
  const parts = String(previewContextKey || "").split(":")
  if (parts.length >= 3 && parts[0] === "document_version") {
    const versionId = parts[1]
    const sitePath = parts.slice(2).join(":")
    return [
      "document-version",
      versionId,
      "site-path",
      cgiEscape(sitePath),
      "table",
      tableIndexValue
    ].join(":")
  }

  return `document-preview:${cgiEscape(previewContextKey || "unknown")}:table:${tableIndexValue}`
}

function resolveTablePreferenceKey(frame, wrapper, table, fallbackIndex) {
  const explicitKey =
    wrapper.dataset.railsTablePreferencesTableKey ||
    table.dataset.railsTablePreferencesTableKey ||
    table.closest("[data-rails-table-preferences-table-key]")?.dataset.railsTablePreferencesTableKey
  if (explicitKey) return explicitKey

  const previewContextKey = frame.contentDocument?.body?.dataset?.docsPortalPreviewContextKey
  return stableTablePreferenceKeyFromContext(previewContextKey, tableIndex(wrapper, fallbackIndex))
}

function collectTableColumns(table) {
  const headerCells = Array.from(table.querySelectorAll("thead tr:first-child th"))
  const fallbackCells = headerCells.length > 0 ? headerCells : Array.from(table.rows[0]?.cells || [])
  const columnCount = Math.max(fallbackCells.length, ...Array.from(table.rows).map((row) => row.cells.length), 0)

  return Array.from({ length: columnCount }, (_, index) => {
    const key = fallbackCells[index]?.dataset?.railsTablePreferencesColumnKey || `column_${index + 1}`
    const label = fallbackCells[index]?.textContent?.trim() || `列${index + 1}`
    return {
      key,
      label,
      visible: true,
      order: (index + 1) * 10
    }
  })
}

function applyColumnKeys(table, columns) {
  Array.from(table.rows).forEach((row) => {
    Array.from(row.cells).forEach((cell, index) => {
      if (!columns[index]) return
      cell.dataset.railsTablePreferencesColumnKey = columns[index].key
    })
  })
}

function mergeTablePreferenceColumns(defaultColumns, savedColumns) {
  const savedByKey = new Map(Array(savedColumns || []).map((column) => [column.key, column]))
  return defaultColumns.map((column, index) => {
    const saved = savedByKey.get(column.key) || {}
    return {
      key: column.key,
      label: column.label,
      visible: saved.visible ?? column.visible,
      order: saved.order ?? column.order ?? (index + 1) * 10
    }
  }).sort((left, right) => Number(left.order) - Number(right.order))
}

function applyTablePreferenceSettings(table, settings) {
  const columns = mergeTablePreferenceColumns(collectTableColumns(table), settings?.columns || [])
  const orderedKeys = columns.map((column) => column.key)
  const visibilityByKey = new Map(columns.map((column) => [column.key, column.visible !== false]))

  Array.from(table.rows).forEach((row) => {
    const keyedCells = new Map(Array.from(row.children).map((cell) => [cell.dataset.railsTablePreferencesColumnKey, cell]))
    orderedKeys.forEach((key) => {
      const cell = keyedCells.get(key)
      if (!cell) return
      row.appendChild(cell)
      cell.hidden = visibilityByKey.get(key) === false
    })
  })

  return {
    columns,
    filters: settings?.filters || {},
    sorts: settings?.sorts || []
  }
}

function preferenceCollectionUrl(tableKey) {
  return `${TABLE_PREFERENCE_COLLECTION_PATH}/${encodeURIComponent(tableKey)}`
}

function preferenceDefaultUrl(tableKey) {
  return `${preferenceCollectionUrl(tableKey)}/default`
}

async function loadTablePreference(tableKey) {
  const response = await fetch(preferenceDefaultUrl(tableKey), { headers: { Accept: "application/json" } })
  if (response.status === 404) return null
  if (!response.ok) throw new Error(`Failed to load table preference: ${response.status}`)
  return response.json()
}

async function saveTablePreference(tableKey, settings) {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content || ""
  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
    "X-CSRF-Token": csrfToken
  }

  const patchResponse = await fetch(preferenceDefaultUrl(tableKey), {
    method: "PATCH",
    headers,
    body: JSON.stringify({ settings })
  })

  if (patchResponse.status !== 404) {
    if (!patchResponse.ok) throw new Error(`Failed to save table preference: ${patchResponse.status}`)
    return patchResponse.json()
  }

  const createResponse = await fetch(preferenceCollectionUrl(tableKey), {
    method: "POST",
    headers,
    body: JSON.stringify({ name: "default", settings })
  })
  if (!createResponse.ok) throw new Error(`Failed to create table preference: ${createResponse.status}`)
  return createResponse.json()
}

function buildPreferencePanel(frameDocument, table, initialSettings, tableKey) {
  const panel = frameDocument.createElement("details")
  panel.className = "portal-table-preference-panel"

  const summary = frameDocument.createElement("summary")
  summary.textContent = "列表示設定"
  panel.appendChild(summary)

  const body = frameDocument.createElement("div")
  body.className = "portal-table-preference-panel__body"

  const rows = frameDocument.createElement("div")
  rows.className = "portal-table-preference-panel__rows"

  const actions = frameDocument.createElement("div")
  actions.className = "portal-table-preference-panel__actions"

  const applyButton = frameDocument.createElement("button")
  applyButton.type = "button"
  applyButton.className = "portal-table-width-button"
  applyButton.textContent = "適用"

  const saveButton = frameDocument.createElement("button")
  saveButton.type = "button"
  saveButton.className = "portal-table-width-button"
  saveButton.textContent = "保存"

  const resetButton = frameDocument.createElement("button")
  resetButton.type = "button"
  resetButton.className = "portal-table-width-button"
  resetButton.textContent = "リセット"

  const status = frameDocument.createElement("span")
  status.className = "portal-table-preference-status"
  status.setAttribute("aria-live", "polite")

  actions.append(applyButton, saveButton, resetButton, status)
  body.append(rows, actions)
  panel.appendChild(body)

  const renderRows = (settings) => {
    rows.innerHTML = ""
    settings.columns.forEach((column) => {
      const label = frameDocument.createElement("label")
      label.className = "portal-table-preference-panel__row"
      label.dataset.railsTablePreferenceColumnKey = column.key

      const checkbox = frameDocument.createElement("input")
      checkbox.type = "checkbox"
      checkbox.checked = column.visible !== false
      checkbox.dataset.railsTablePreferenceVisible = "true"

      const text = frameDocument.createElement("span")
      text.textContent = column.label

      label.append(checkbox, text)
      rows.appendChild(label)
    })
  }

  const settingsFromRows = () => {
    const columns = Array.from(rows.querySelectorAll("[data-rails-table-preference-column-key]")).map((row, index) => ({
      key: row.dataset.railsTablePreferenceColumnKey,
      label: row.textContent.trim(),
      visible: row.querySelector("[data-rails-table-preference-visible]")?.checked !== false,
      order: (index + 1) * 10
    }))
    return {
      columns,
      filters: initialSettings.filters || {},
      sorts: initialSettings.sorts || []
    }
  }

  let currentSettings = {
    columns: mergeTablePreferenceColumns(initialSettings.columns, initialSettings.columns),
    filters: initialSettings.filters || {},
    sorts: initialSettings.sorts || []
  }

  renderRows(currentSettings)
  currentSettings = applyTablePreferenceSettings(table, currentSettings)

  applyButton.addEventListener("click", () => {
    currentSettings = applyTablePreferenceSettings(table, settingsFromRows())
    status.textContent = "表示を更新しました"
    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
  })

  saveButton.addEventListener("click", async () => {
    currentSettings = applyTablePreferenceSettings(table, settingsFromRows())
    saveButton.disabled = true
    status.textContent = "保存中…"
    try {
      const payload = await saveTablePreference(tableKey, currentSettings)
      currentSettings = applyTablePreferenceSettings(table, payload?.settings || currentSettings)
      renderRows(currentSettings)
      status.textContent = "保存しました"
    } catch (_error) {
      status.textContent = "保存できませんでした"
    } finally {
      saveButton.disabled = false
      window.setTimeout(() => {
        status.textContent = ""
      }, 1800)
    }
  })

  resetButton.addEventListener("click", () => {
    currentSettings = applyTablePreferenceSettings(table, { columns: collectTableColumns(table), filters: {}, sorts: [] })
    renderRows(currentSettings)
    status.textContent = "既定表示に戻しました"
    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
  })

  return {
    panel,
    applyLoadedSettings(settings) {
      currentSettings = applyTablePreferenceSettings(table, {
        columns: mergeTablePreferenceColumns(initialSettings.columns, settings?.columns || []),
        filters: settings?.filters || {},
        sorts: settings?.sorts || []
      })
      renderRows(currentSettings)
    }
  }
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
    const tableKey = resolveTablePreferenceKey(frame, wrapper, table, index)
    wrapper.dataset.railsTablePreferencesTableKey = tableKey
    table.dataset.railsTablePreferencesTableKey = tableKey

    const columns = collectTableColumns(table)
    applyColumnKeys(table, columns)

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

    const preferencePanel = buildPreferencePanel(frameDocument, table, { columns, filters: {}, sorts: [] }, tableKey)
    target.appendChild(preferencePanel.panel)

    input.addEventListener("input", () => updateTableSearch(table, input, count))
    clearButton.addEventListener("click", () => {
      input.value = ""
      updateTableSearch(table, input, count)
      input.focus()
    })
    resetSettingsButton.addEventListener("click", () => resetTableDisplaySettings(frame, index, wrapper, table, copyStatus))
    copyCsvButton.addEventListener("click", () => copyText(tableToCsv(table), copyStatus))
    copyMarkdownButton.addEventListener("click", () => copyText(tableToMarkdown(table), copyStatus))

    loadTablePreference(tableKey)
      .then((payload) => {
        if (!payload?.settings) return
        preferencePanel.applyLoadedSettings(payload.settings)
      })
      .catch(() => {
        // Keep the local bridge usable even when saved presets are unavailable.
      })
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
