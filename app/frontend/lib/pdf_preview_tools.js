function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function styleShortcutCue(cue) {
  cue.style.display = "block"
  cue.style.marginTop = ".25rem"
  cue.style.fontSize = ".875rem"
  cue.style.lineHeight = "1.4"
  cue.style.color = "var(--doc-text-muted, #64748b)"
}

function ensureShortcutCue(container, status) {
  let cue = container.querySelector("[data-pdf-preview-shortcut-cue]")
  if (!cue) {
    cue = document.createElement("span")
    cue.dataset.pdfPreviewShortcutCue = "true"
    cue.className = "preview-shortcut-cue"
    status.insertAdjacentElement("afterend", cue)
  }
  styleShortcutCue(cue)
  cue.textContent = "ショートカット: h / Hで高さ切替。表示高さはこのブラウザに保存されます。"
  return cue
}

function setupPdfPreview(container) {
  if (container.dataset.pdfPreviewToolsReady === "true") return null
  container.dataset.pdfPreviewToolsReady = "true"

  const frame = container.querySelector("[data-pdf-preview-frame]")
  const toggle = container.querySelector("[data-pdf-preview-height-toggle]")
  const status = container.querySelector("[data-pdf-preview-status]")
  if (!frame || !toggle || !status) return null

  ensureShortcutCue(container, status)

  const storageKey = `docsPortal.pdfPreviewHeight:${container.dataset.pdfPreviewStorageKey || window.location.pathname}`
  const readLarge = () => window.localStorage.getItem(storageKey) === "large"
  const writeLarge = (enabled) => window.localStorage.setItem(storageKey, enabled ? "large" : "normal")

  const applyHeight = (large) => {
    frame.style.minHeight = large ? "90vh" : "75vh"
    toggle.setAttribute("aria-pressed", String(large))
    toggle.textContent = large ? "標準高さに戻す" : "大きく表示"
    const toggleLabel = large ? "標準高さに戻す" : "大きく表示"
    toggle.setAttribute("aria-label", `${toggleLabel} (ショートカット: h / H)`)
    toggle.title = `${toggleLabel} (h / H)`
    status.textContent = large ? "大きく表示しています" : "標準高さで表示しています"
    writeLarge(large)
  }

  const toggleHeight = () => {
    applyHeight(toggle.getAttribute("aria-pressed") !== "true")
  }

  const handleKeydown = (event) => {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || isEditableTarget(event.target)) return
    if (event.key !== "h" && event.key !== "H") return

    event.preventDefault()
    toggleHeight()
  }

  toggle.addEventListener("click", toggleHeight)
  document.addEventListener("keydown", handleKeydown)

  applyHeight(readLarge())

  return () => {
    toggle.removeEventListener("click", toggleHeight)
    document.removeEventListener("keydown", handleKeydown)
    delete container.dataset.pdfPreviewToolsReady
  }
}

export function setupPdfPreviewTools() {
  return Array.from(document.querySelectorAll("[data-pdf-preview-tools]"))
    .map((container) => setupPdfPreview(container))
    .filter(Boolean)
}
