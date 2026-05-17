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

function archiveEntryDirectory(row) {
  return row.dataset.archivePreviewEntryDirectory || "/"
}

function archiveEntryDownloadCandidate(row) {
  return row.dataset.archivePreviewEntryDownloadCandidate === "true"
}

function archiveEntrySafe(row) {
  return row.dataset.archivePreviewEntrySafe === "true"
}

function archiveEntryTextPreviewCandidate(row) {
  return row.dataset.archivePreviewEntryTextPreviewCandidate === "true"
}

function archiveEntryType(row) {
  return row.dataset.archivePreviewEntryType || "file"
}

function archiveEntrySize(row) {
  return Number(row.dataset.archivePreviewEntrySize || 0)
}

function archiveEntryMatchesCandidate(row, candidateFilter) {
  if (candidateFilter === "text-preview") return archiveEntryTextPreviewCandidate(row)
  if (candidateFilter === "download") return archiveEntryDownloadCandidate(row)
  if (candidateFilter === "unavailable") return !archiveEntryDownloadCandidate(row)

  return true
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

async function copyText(text, status, successMessage) {
  try {
    await navigator.clipboard.writeText(text)
    setTemporaryStatus(status, successMessage)
  } catch (_error) {
    setTemporaryStatus(status, "コピーできませんでした")
  }
}

function sortValue(row, key) {
  if (key === "type") return archiveEntryType(row)
  if (key === "size") return archiveEntrySize(row)
  return archiveEntryText(row)
}

function compareRows(left, right, key, direction) {
  const leftValue = sortValue(left, key)
  const rightValue = sortValue(right, key)
  const comparison = typeof leftValue === "number" && typeof rightValue === "number" ?
    leftValue - rightValue :
    String(leftValue).localeCompare(String(rightValue), "ja")

  return direction === "desc" ? -comparison : comparison
}

function activeFilterLabel(candidateFilter, directoryFilter, typeFilter) {
  const labels = []
  if (candidateFilter.value !== "all") labels.push(`候補:${candidateFilter.value}`)
  if (directoryFilter.value !== "all") labels.push(`dir:${directoryFilter.value}`)
  if (typeFilter.value !== "all") labels.push(`種別:${typeFilter.value}`)
  return labels.length > 0 ? ` / ${labels.join(" / ")}` : ""
}

function setupArchivePreview(container) {
  if (container.dataset.archivePreviewToolsReady === "true") return
  container.dataset.archivePreviewToolsReady = "true"
  injectArchivePreviewStyle()

  const input = container.querySelector("[data-archive-preview-search-input]")
  const candidateFilter = container.querySelector("[data-archive-preview-candidate-filter]")
  const directoryFilter = container.querySelector("[data-archive-preview-directory-filter]")
  const typeFilter = container.querySelector("[data-archive-preview-type-filter]")
  const resetButton = container.querySelector("[data-archive-preview-reset]")
  const copyVisibleButton = container.querySelector("[data-archive-preview-copy-visible]")
  const count = container.querySelector("[data-archive-preview-count]")
  const status = container.querySelector("[data-archive-preview-status]")
  const tableBody = container.querySelector("[data-archive-preview-entries]")
  const sortButtons = Array.from(container.querySelectorAll("[data-archive-preview-sort]"))
  const rows = Array.from(container.querySelectorAll("[data-archive-preview-entry]"))
  const copyButtons = Array.from(container.querySelectorAll("[data-archive-preview-copy-entry]"))
  const copyDirectoryButtons = Array.from(container.querySelectorAll("[data-archive-preview-copy-directory]"))
  if (!input || !candidateFilter || !directoryFilter || !typeFilter || !resetButton || !copyVisibleButton || !count || !status || !tableBody || rows.length === 0) return

  let sortKey = "name"
  let sortDirection = "asc"

  const updateSortButtons = () => {
    sortButtons.forEach((button) => {
      const active = button.dataset.archivePreviewSort === sortKey
      button.setAttribute("aria-pressed", String(active))
      button.textContent = active ? `${button.dataset.archivePreviewSortLabel} ${sortDirection === "asc" ? "↑" : "↓"}` : button.dataset.archivePreviewSortLabel
    })
  }

  const applySort = () => {
    rows
      .slice()
      .sort((left, right) => compareRows(left, right, sortKey, sortDirection))
      .forEach((row) => tableBody.appendChild(row))
    updateSortButtons()
  }

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    const selectedCandidate = candidateFilter.value
    const selectedDirectory = directoryFilter.value
    const selectedType = typeFilter.value
    let matchedCount = 0
    let visibleCount = 0

    rows.forEach((row) => {
      const textMatched = query.length === 0 || archiveEntryText(row).includes(query)
      const candidateMatched = archiveEntryMatchesCandidate(row, selectedCandidate)
      const directoryMatched = selectedDirectory === "all" || archiveEntryDirectory(row) === selectedDirectory
      const typeMatched = selectedType === "all" || archiveEntryType(row) === selectedType
      const matched = query.length > 0 && textMatched
      const visible = textMatched && candidateMatched && directoryMatched && typeMatched
      row.classList.toggle("is-archive-preview-match", matched)
      row.hidden = !visible
      if (query.length > 0 && textMatched) matchedCount += 1
      if (visible) visibleCount += 1
    })

    const filterLabel = activeFilterLabel(candidateFilter, directoryFilter, typeFilter)
    count.textContent = query.length === 0 ? `${visibleCount}/${rows.length}件表示${filterLabel}` : `${matchedCount}/${rows.length}件一致 / ${visibleCount}件表示${filterLabel}`
  }

  const resetControls = () => {
    input.value = ""
    candidateFilter.value = "all"
    directoryFilter.value = "all"
    typeFilter.value = "all"
    sortKey = "name"
    sortDirection = "asc"
    updateSearch()
    applySort()
  }

  input.addEventListener("input", updateSearch)
  input.addEventListener("search", updateSearch)
  candidateFilter.addEventListener("change", updateSearch)
  directoryFilter.addEventListener("change", updateSearch)
  typeFilter.addEventListener("change", updateSearch)
  resetButton.addEventListener("click", () => {
    resetControls()
    input.focus()
  })

  sortButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const nextKey = button.dataset.archivePreviewSort || "name"
      sortDirection = sortKey === nextKey && sortDirection === "asc" ? "desc" : "asc"
      sortKey = nextKey
      applySort()
    })
  })

  copyVisibleButton.addEventListener("click", () => {
    const visibleEntryRows = visibleRows(rows)
    const entryNames = visibleEntryRows.map(archiveEntryName).filter(Boolean)
    const unsafeCount = visibleEntryRows.filter((row) => !archiveEntrySafe(row)).length
    const unsafeNote = unsafeCount > 0 ? `（unsafe ${unsafeCount}件を含みます）` : ""
    const filterNote = activeFilterLabel(candidateFilter, directoryFilter, typeFilter)
    copyText(entryNames.join("\n"), status, `${entryNames.length}件の表示中パスをコピーしました${filterNote}${unsafeNote}`)
  })

  copyButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const row = button.closest("[data-archive-preview-entry]")
      const entryName = row ? archiveEntryName(row) : ""
      const unsafeNote = row && !archiveEntrySafe(row) ? "（unsafe path）" : ""
      copyText(entryName, status, `パスをコピーしました${unsafeNote}`)
    })
  })

  copyDirectoryButtons.forEach((button) => {
    button.addEventListener("click", () => {
      copyText(button.dataset.archivePreviewCopyDirectory || "", status, "ディレクトリパスをコピーしました")
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
      resetControls()
      input.blur()
    }
  })

  updateSearch()
  applySort()
}

export function setupArchivePreviewTools() {
  document.querySelectorAll("[data-archive-preview-tools]").forEach(setupArchivePreview)
}
