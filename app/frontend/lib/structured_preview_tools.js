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
    .line-preview__row:target,
    .line-preview__row.is-text-preview-anchor-target {
      background: #dbeafe;
      box-shadow: inset 4px 0 0 #2563eb;
      scroll-margin-top: 1rem;
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

function markTextPreviewAnchorTarget(row, active) {
  row.classList.toggle("is-text-preview-anchor-target", active)

  if (active) {
    row.setAttribute("aria-current", "location")
  } else {
    row.removeAttribute("aria-current")
  }
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
  if (container.dataset.structuredPreviewToolsReady === "true") return null
  container.dataset.structuredPreviewToolsReady = "true"
  injectStructuredPreviewStyle()

  const input = container.querySelector("[data-structured-preview-search-input]")
  const clearButton = container.querySelector("[data-structured-preview-search-clear]")
  const filterButton = container.querySelector("[data-structured-preview-filter-matches]")
  const copyButton = container.querySelector("[data-structured-preview-copy]")
  const count = container.querySelector("[data-structured-preview-count]")
  const status = container.querySelector("[data-structured-preview-status]")
  const code = container.querySelector("[data-structured-preview-code]")
  const cleanupReadyFlag = () => delete container.dataset.structuredPreviewToolsReady
  if (!input || !clearButton || !filterButton || !copyButton || !count || !status || !code) return cleanupReadyFlag

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

  const handleClearClick = () => {
    clearSearch()
    input.focus()
  }

  const handleFilterClick = () => {
    filterMatches = !filterMatches
    updateFilterButton()
    updateSearch()
  }

  const handleCopyClick = async () => {
    try {
      await navigator.clipboard.writeText(lines.map((line) => line.textContent || "").join("\n"))
      status.textContent = "コピーしました"
    } catch (_error) {
      status.textContent = "コピーできませんでした"
    }

    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
  }

  const handleKeydown = (event) => {
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
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  clearButton.addEventListener("click", handleClearClick)
  filterButton.addEventListener("click", handleFilterClick)
  copyButton.addEventListener("click", handleCopyClick)
  document.addEventListener("keydown", handleKeydown)

  updateFilterButton()
  updateSearch()

  return () => {
    input.removeEventListener("input", updateSearch)
    input.removeEventListener("search", updateSearch)
    clearButton.removeEventListener("click", handleClearClick)
    filterButton.removeEventListener("click", handleFilterClick)
    copyButton.removeEventListener("click", handleCopyClick)
    document.removeEventListener("keydown", handleKeydown)
    cleanupReadyFlag()
  }
}

function setupTextPreview(container) {
  if (container.dataset.textPreviewToolsReady === "true") return null
  container.dataset.textPreviewToolsReady = "true"
  injectStructuredPreviewStyle()

  const input = container.querySelector("[data-text-preview-search-input]")
  const clearButton = container.querySelector("[data-text-preview-search-clear]")
  const filterButton = container.querySelector("[data-text-preview-filter-matches]")
  const copyButton = container.querySelector("[data-text-preview-copy]")
  const count = container.querySelector("[data-text-preview-count]")
  const status = container.querySelector("[data-text-preview-status]")
  const rows = Array.from(container.querySelectorAll("[data-text-preview-line]"))
  const cleanupReadyFlag = () => delete container.dataset.textPreviewToolsReady
  if (!input || !clearButton || !filterButton || !copyButton || !count || !status || rows.length === 0) return cleanupReadyFlag

  let filterMatches = false

  const updateAnchorTarget = () => {
    const targetId = decodeURIComponent(window.location.hash.replace(/^#/, ""))
    rows.forEach((row) => {
      markTextPreviewAnchorTarget(row, targetId.length > 0 && row.id === targetId)
    })
  }

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

  const handleClearClick = () => {
    clearSearch()
    input.focus()
  }

  const handleFilterClick = () => {
    filterMatches = !filterMatches
    updateFilterButton()
    updateSearch()
  }

  const handleCopyClick = async () => {
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
  }

  const handleKeydown = (event) => {
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
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  clearButton.addEventListener("click", handleClearClick)
  filterButton.addEventListener("click", handleFilterClick)
  copyButton.addEventListener("click", handleCopyClick)
  document.addEventListener("keydown", handleKeydown)
  window.addEventListener("hashchange", updateAnchorTarget)

  updateFilterButton()
  updateSearch()
  updateAnchorTarget()

  return () => {
    input.removeEventListener("input", updateSearch)
    input.removeEventListener("search", updateSearch)
    clearButton.removeEventListener("click", handleClearClick)
    filterButton.removeEventListener("click", handleFilterClick)
    copyButton.removeEventListener("click", handleCopyClick)
    document.removeEventListener("keydown", handleKeydown)
    window.removeEventListener("hashchange", updateAnchorTarget)
    rows.forEach((row) => markTextPreviewAnchorTarget(row, false))
    cleanupReadyFlag()
  }
}

export function setupStructuredPreviewTools() {
  const cleanups = []
  document.querySelectorAll("[data-structured-preview-tools]").forEach((container) => {
    const cleanup = setupStructuredPreview(container)
    if (cleanup) cleanups.push(cleanup)
  })
  document.querySelectorAll("[data-text-preview-tools]").forEach((container) => {
    const cleanup = setupTextPreview(container)
    if (cleanup) cleanups.push(cleanup)
  })
  return cleanups
}
