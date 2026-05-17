function injectTextPreviewStyle() {
  if (document.querySelector("style[data-text-preview-tools]")) return

  const style = document.createElement("style")
  style.dataset.textPreviewTools = "true"
  style.textContent = `
    .line-preview__row.is-text-preview-match {
      background: #fff7cc;
      box-shadow: inset 4px 0 0 #f59e0b;
    }
  `
  document.head?.appendChild(style)
}

function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function rowText(row) {
  return (row.querySelector(".line-preview__code")?.textContent || row.textContent || "").toLowerCase()
}

function setupTextPreview(container) {
  if (container.dataset.textPreviewToolsReady === "true") return
  container.dataset.textPreviewToolsReady = "true"
  injectTextPreviewStyle()

  const input = container.querySelector("[data-text-preview-search-input]")
  const clearButton = container.querySelector("[data-text-preview-search-clear]")
  const filterButton = container.querySelector("[data-text-preview-filter-matches]")
  const copyButton = container.querySelector("[data-text-preview-copy]")
  const count = container.querySelector("[data-text-preview-count]")
  const status = container.querySelector("[data-text-preview-status]")
  const rows = Array.from(container.querySelectorAll("[data-text-preview-line]"))
  if (!input || !clearButton || !filterButton || !copyButton || !count || !status || rows.length === 0) return

  let filterMatches = false

  const updateFilterButton = () => {
    filterButton.setAttribute("aria-pressed", String(filterMatches))
    filterButton.textContent = filterMatches ? "一致行のみ表示中" : "一致行のみ表示"
  }

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    let matchedCount = 0
    let visibleCount = 0

    rows.forEach((row) => {
      const matched = query.length > 0 && rowText(row).includes(query)
      const visible = query.length === 0 || !filterMatches || matched
      row.classList.toggle("is-text-preview-match", matched)
      row.hidden = !visible
      if (matched) matchedCount += 1
      if (visible) visibleCount += 1
    })

    count.textContent = query.length === 0 ? `${rows.length}行` : `${matchedCount}/${rows.length}行一致 / ${visibleCount}行表示`
  }

  const clearSearch = () => {
    input.value = ""
    filterMatches = false
    updateFilterButton()
    updateSearch()
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  clearButton.addEventListener("click", () => {
    clearSearch()
    input.focus()
  })

  filterButton.addEventListener("click", () => {
    filterMatches = !filterMatches
    updateFilterButton()
    updateSearch()
  })

  copyButton.addEventListener("click", async () => {
    try {
      const text = rows.map((row) => row.querySelector(".line-preview__code")?.textContent || "").join("\n")
      await navigator.clipboard.writeText(text)
      status.textContent = "コピーしました"
    } catch (_error) {
      status.textContent = "コピーできませんでした"
    }

    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
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

  updateFilterButton()
  updateSearch()
}

export function setupTextPreviewTools() {
  document.querySelectorAll("[data-text-preview-tools]").forEach(setupTextPreview)
}
