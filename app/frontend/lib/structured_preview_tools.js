function injectStructuredPreviewStyle() {
  if (document.querySelector("style[data-structured-preview-tools]")) return

  const style = document.createElement("style")
  style.dataset.structuredPreviewTools = "true"
  style.textContent = `
    .structured-preview-line {
      display: block;
      min-height: 1.3em;
      white-space: pre-wrap;
    }
    .structured-preview-line.is-structured-preview-match,
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

function lineText(line) {
  return (line.textContent || "").toLowerCase()
}

function previewRowText(row) {
  return (row.querySelector(".line-preview__code")?.textContent || row.textContent || "").toLowerCase()
}

function prepareCodeLines(code) {
  if (code.dataset.structuredPreviewLinesReady === "true") {
    return Array.from(code.querySelectorAll(".structured-preview-line"))
  }

  code.dataset.structuredPreviewLinesReady = "true"
  const source = code.textContent || ""
  code.textContent = ""

  source.split("\n").forEach((text) => {
    const line = document.createElement("span")
    line.className = "structured-preview-line"
    line.textContent = text.length > 0 ? text : " "
    code.appendChild(line)
  })

  return Array.from(code.querySelectorAll(".structured-preview-line"))
}

function setupStructuredPreview(container) {
  if (container.dataset.structuredPreviewToolsReady === "true") return
  container.dataset.structuredPreviewToolsReady = "true"
  injectStructuredPreviewStyle()

  const input = container.querySelector("[data-structured-preview-search-input]")
  const clearButton = container.querySelector("[data-structured-preview-search-clear]")
  const filterButton = container.querySelector("[data-structured-preview-filter-matches]")
  const copyButton = container.querySelector("[data-structured-preview-copy]")
  const count = container.querySelector("[data-structured-preview-count]")
  const status = container.querySelector("[data-structured-preview-status]")
  const code = container.querySelector("[data-structured-preview-code]")
  if (!input || !clearButton || !filterButton || !copyButton || !count || !status || !code) return

  const lines = prepareCodeLines(code)
  let filterMatches = false

  const updateFilterButton = () => {
    filterButton.setAttribute("aria-pressed", String(filterMatches))
    filterButton.textContent = filterMatches ? "一致行のみ表示中" : "一致行のみ表示"
  }

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    let matchedCount = 0
    let visibleCount = 0

    lines.forEach((line) => {
      const matched = query.length > 0 && lineText(line).includes(query)
      const visible = query.length === 0 || !filterMatches || matched
      line.classList.toggle("is-structured-preview-match", matched)
      line.hidden = !visible
      if (matched) matchedCount += 1
      if (visible) visibleCount += 1
    })

    count.textContent = query.length === 0 ? `${lines.length}行` : `${matchedCount}/${lines.length}行一致 / ${visibleCount}行表示`
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
      await navigator.clipboard.writeText(lines.map((line) => line.textContent || "").join("\n"))
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

function setupTextPreview(container) {
  if (container.dataset.textPreviewToolsReady === "true") return
  container.dataset.textPreviewToolsReady = "true"
  injectStructuredPreviewStyle()

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
      const matched = query.length > 0 && previewRowText(row).includes(query)
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

export function setupStructuredPreviewTools() {
  document.querySelectorAll("[data-structured-preview-tools]").forEach(setupStructuredPreview)
  document.querySelectorAll("[data-text-preview-tools]").forEach(setupTextPreview)
}
