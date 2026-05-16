function normalizeText(value) {
  return (value || "").toString().trim().toLowerCase()
}

function injectDocumentFileSearchStyle() {
  if (document.querySelector("style[data-document-file-search-style]")) return

  const style = document.createElement("style")
  style.dataset.documentFileSearchStyle = "true"
  style.textContent = `
    tr.is-document-file-search-match > td,
    tr.is-document-file-search-match > th {
      background: #fff7cc;
      box-shadow: inset 4px 0 0 #f59e0b;
    }
    tr.is-document-file-search-context > td,
    tr.is-document-file-search-context > th {
      background: #f8fafc;
      color: var(--doc-text-muted, #64748b);
    }
  `
  document.head?.appendChild(style)
}

function firstPresentAttribute(element, names) {
  for (const name of names) {
    const value = element.getAttribute(name)
    if (value) return value
  }

  return null
}

function rowKey(row) {
  return firstPresentAttribute(row, [
    "data-tree-view-node-id",
    "data-tree-node-id",
    "data-node-id",
    "data-item-id",
    "id"
  ])
}

function parentRowKey(row) {
  return firstPresentAttribute(row, [
    "data-tree-view-parent-id",
    "data-tree-parent-id",
    "data-parent-id",
    "data-parent-node-id"
  ])
}

function rowMatchesQuery(row, query) {
  return query.length > 0 && normalizeText(row.textContent).includes(query)
}

function visibleRowsForQuery(rows, query, matchedRows) {
  if (query.length === 0) return new Set(rows)

  const rowsByKey = new Map()
  rows.forEach((row) => {
    const key = rowKey(row)
    if (key) rowsByKey.set(key, row)
  })

  const visibleRows = new Set()

  rows.forEach((row) => {
    if (!rowMatchesQuery(row, query)) return

    matchedRows.add(row)
    visibleRows.add(row)

    let parentKey = parentRowKey(row)
    const visitedParentKeys = new Set()
    while (parentKey && !visitedParentKeys.has(parentKey)) {
      visitedParentKeys.add(parentKey)
      const parentRow = rowsByKey.get(parentKey)
      if (!parentRow) break

      visibleRows.add(parentRow)
      parentKey = parentRowKey(parentRow)
    }
  })

  return visibleRows
}

function setupFileListSearch(container) {
  if (container.dataset.fileListSearchReady === "true") return
  container.dataset.fileListSearchReady = "true"
  injectDocumentFileSearchStyle()

  const input = container.querySelector("[data-document-file-search-input]")
  const clearButton = container.querySelector("[data-document-file-search-clear]")
  const count = container.querySelector("[data-document-file-search-count]")
  const table = container.querySelector("[data-document-file-search-table]")
  if (!input || !clearButton || !count || !table) return

  const rows = Array.from(table.querySelectorAll("tbody tr"))

  const update = () => {
    const query = normalizeText(input.value)
    const matchedRows = new Set()
    const visibleRows = visibleRowsForQuery(rows, query, matchedRows)
    let visibleCount = 0
    let matchedCount = 0

    rows.forEach((row) => {
      const visible = visibleRows.has(row)
      const matched = matchedRows.has(row)
      row.hidden = !visible
      row.classList.toggle("is-document-file-search-match", matched)
      row.classList.toggle("is-document-file-search-context", visible && query.length > 0 && !matched)
      if (visible) visibleCount += 1
      if (matched) matchedCount += 1
    })

    count.textContent = query.length === 0 ? `${rows.length}件` : `${matchedCount}件一致 / ${visibleCount}件表示`
  }

  input.addEventListener("input", update)
  input.addEventListener("search", update)
  clearButton.addEventListener("click", () => {
    input.value = ""
    update()
    input.focus()
  })

  update()
}

export function setupDocumentFileListSearch() {
  document.querySelectorAll("[data-document-file-search]").forEach(setupFileListSearch)
}
