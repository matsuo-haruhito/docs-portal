function normalizeText(value) {
  return (value || "").toString().trim().toLowerCase()
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
    let visibleCount = 0

    rows.forEach((row) => {
      const matched = query.length === 0 || normalizeText(row.textContent).includes(query)
      row.hidden = !matched
      if (matched) visibleCount += 1
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
