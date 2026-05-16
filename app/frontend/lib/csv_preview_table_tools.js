function escapeCsvCell(value) {
  const text = (value || "").toString()
  return /[",\n\r]/.test(text) ? `"${text.replaceAll("\"", "\"\"")}"` : text
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

function setupCsvPreviewTable(container) {
  if (container.dataset.csvPreviewToolsReady === "true") return
  container.dataset.csvPreviewToolsReady = "true"

  const input = container.querySelector("[data-csv-preview-search-input]")
  const clearButton = container.querySelector("[data-csv-preview-search-clear]")
  const copyButton = container.querySelector("[data-csv-preview-copy]")
  const count = container.querySelector("[data-csv-preview-count]")
  const status = container.querySelector("[data-csv-preview-status]")
  const table = container.querySelector("[data-csv-preview-table]")
  if (!input || !clearButton || !copyButton || !count || !status || !table) return

  const rows = Array.from(table.querySelectorAll("tbody tr"))

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

  updateSearch()
}

export function setupCsvPreviewTableTools() {
  document.querySelectorAll("[data-csv-preview-tools]").forEach(setupCsvPreviewTable)
}
