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

function setupArchivePreview(container) {
  if (container.dataset.archivePreviewToolsReady === "true") return
  container.dataset.archivePreviewToolsReady = "true"
  injectArchivePreviewStyle()

  const input = container.querySelector("[data-archive-preview-search-input]")
  const clearButton = container.querySelector("[data-archive-preview-search-clear]")
  const count = container.querySelector("[data-archive-preview-count]")
  const status = container.querySelector("[data-archive-preview-status]")
  const rows = Array.from(container.querySelectorAll("[data-archive-preview-entry]"))
  const copyButtons = Array.from(container.querySelectorAll("[data-archive-preview-copy-entry]"))
  if (!input || !clearButton || !count || !status || rows.length === 0) return

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    let matchedCount = 0
    let visibleCount = 0

    rows.forEach((row) => {
      const matched = query.length > 0 && archiveEntryText(row).includes(query)
      const visible = query.length === 0 || matched
      row.classList.toggle("is-archive-preview-match", matched)
      row.hidden = !visible
      if (matched) matchedCount += 1
      if (visible) visibleCount += 1
    })

    count.textContent = query.length === 0 ? `${rows.length}件` : `${matchedCount}/${rows.length}件一致 / ${visibleCount}件表示`
  }

  const clearSearch = () => {
    input.value = ""
    updateSearch()
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  clearButton.addEventListener("click", () => {
    clearSearch()
    input.focus()
  })

  copyButtons.forEach((button) => {
    button.addEventListener("click", async () => {
      const row = button.closest("[data-archive-preview-entry]")
      const entryName = row ? archiveEntryName(row) : ""

      try {
        await navigator.clipboard.writeText(entryName)
        status.textContent = "パスをコピーしました"
      } catch (_error) {
        status.textContent = "コピーできませんでした"
      }

      window.setTimeout(() => {
        status.textContent = ""
      }, 1800)
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
