function injectArchivePreviewStyle() {
  if (document.querySelector("style[data-archive-preview-tools]")) return

  const style = document.createElement("style")
  style.dataset.archivePreviewTools = "true"
  style.textContent = `
    tr.is-archive-preview-match {
      background: #fff7cc;
      box-shadow: inset 4px 0 0 #f59e0b;
    }
  `
  document.head?.appendChild(style)
}

function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function archiveEntryName(row) {
  return row.querySelector("[data-archive-preview-entry-name]")?.textContent || ""
}

function archiveEntryText(row) {
  return archiveEntryName(row).toLowerCase()
}

function archiveEntryType(row) {
  return row.dataset.archivePreviewEntryType || "file"
}

function visibleRows(rows) {
  return rows.filter((row) => !row.hidden)
}

function setTemporaryStatus(status, message) {
  status.textContent = message

  window.setTimeout(() => {
    status.textContent = ""
  }, 1800)
}

function setupArchivePreview(container) {
  if (container.dataset.archivePreviewToolsReady === "true") return
  container.dataset.archivePreviewToolsReady = "true"
  injectArchivePreviewStyle()

  const input = container.querySelector("[data-archive-preview-search-input]")
  const typeFilter = container.querySelector("[data-archive-preview-type-filter]")
  const clearButton = container.querySelector("[data-archive-preview-search-clear]")
  const copyVisibleButton = container.querySelector("[data-archive-preview-copy-visible]")
  const count = container.querySelector("[data-archive-preview-count]")
  const status = container.querySelector("[data-archive-preview-status]")
  const rows = Array.from(container.querySelectorAll("[data-archive-preview-entry]"))
  const copyButtons = Array.from(container.querySelectorAll("[data-archive-preview-copy-entry]"))
  if (!input || !typeFilter || !clearButton || !copyVisibleButton || !count || !status || rows.length === 0) return

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    const selectedType = typeFilter.value
    let matchedCount = 0
    let visibleCount = 0

    rows.forEach((row) => {
      const textMatched = query.length === 0 || archiveEntryText(row).includes(query)
      const typeMatched = selectedType === "all" || archiveEntryType(row) === selectedType
      const matched = query.length > 0 && textMatched
      const visible = textMatched && typeMatched
      row.classList.toggle("is-archive-preview-match", matched)
      row.hidden = !visible
      if (query.length > 0 && textMatched) matchedCount += 1
      if (visible) visibleCount += 1
    })

    const typeLabel = selectedType === "all" ? "" : ` / ${selectedType}`
    count.textContent = query.length === 0 ? `${visibleCount}/${rows.length}件表示${typeLabel}` : `${matchedCount}/${rows.length}件一致 / ${visibleCount}件表示${typeLabel}`
  }

  const clearSearch = () => {
    input.value = ""
    typeFilter.value = "all"
    updateSearch()
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  typeFilter.addEventListener("change", updateSearch)
  clearButton.addEventListener("click", () => {
    clearSearch()
    input.focus()
  })

  copyVisibleButton.addEventListener("click", async () => {
    const entryNames = visibleRows(rows).map(archiveEntryName).filter(Boolean)

    try {
      await navigator.clipboard.writeText(entryNames.join("\n"))
      setTemporaryStatus(status, `${entryNames.length}件のパスをコピーしました`)
    } catch (_error) {
      setTemporaryStatus(status, "コピーできませんでした")
    }
  })

  copyButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const row = button.closest("[data-archive-preview-entry]")
      const entryName = row ? archiveEntryName(row) : ""

      try {
        await navigator.clipboard.writeText(entryName)
        setTemporaryStatus(status, "パスをコピーしました")
      } catch (_error) {
        setTemporaryStatus(status, "コピーできませんでした")
      }
    })
  })

  document.addEventListener("keydown", (event) => {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return

    if (event.key === "/" && !isEditableTarget(event.target)) {
      event.preventDefault()
      input.focus()
      input.select()
      return
    }

    if (event.key === "Escape" && document.activeElement === input) {
      event.preventDefault()
      clearSearch()
      input.blur()
    }
  })

  updateSearch()
}

export function setupArchivePreviewTools() {
  document.querySelectorAll("[data-archive-preview-tools]").forEach(setupArchivePreview)
}
