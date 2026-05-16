function normalizeText(value) {
  return (value || "").toString().trim().toLowerCase()
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

function visibleRowsForQuery(rows, query) {
  if (query.length === 0) return new Set(rows)

  const rowsByKey = new Map()
  rows.forEach((row) => {
    const key = rowKey(row)
    if (key) rowsByKey.set(key, row)
  })

  const visibleRows = new Set()

  rows.forEach((row) => {
    if (!normalizeText(row.textContent).includes(query)) return

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

  const input = container.querySelector("[data-document-file-search-input]")
  const clearButton = container.querySelector("[data-document-file-search-clear]")
  const count = container.querySelector("[data-document-file-search-count]")
  const table = container.querySelector("[data-document-file-search-table]")
  if (!input || !clearButton || !count || !table) return

  const rows = Array.from(table.querySelectorAll("tbody tr"))

  const update = () => {
    const query = normalizeText(input.value)
    const visibleRows = visibleRowsForQuery(rows, query)
    let visibleCount = 0

    rows.forEach((row) => {
      const visible = visibleRows.has(row)
      row.hidden = !visible
      if (visible) visibleCount += 1
    })

    count.textContent = query.length === 0 ? `${rows.length}件` : `${visibleCount}/${rows.length}件`
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
