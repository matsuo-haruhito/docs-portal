function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function setupPdfPreview(container) {
  if (container.dataset.pdfPreviewToolsReady === "true") return
  container.dataset.pdfPreviewToolsReady = "true"

  const frame = container.querySelector("[data-pdf-preview-frame]")
  const toggle = container.querySelector("[data-pdf-preview-height-toggle]")
  const status = container.querySelector("[data-pdf-preview-status]")
  if (!frame || !toggle || !status) return

  const storageKey = `docsPortal.pdfPreviewHeight:${container.dataset.pdfPreviewStorageKey || window.location.pathname}`
  const readLarge = () => window.localStorage.getItem(storageKey) === "large"
  const writeLarge = (enabled) => window.localStorage.setItem(storageKey, enabled ? "large" : "normal")

  const applyHeight = (large) => {
    frame.style.minHeight = large ? "90vh" : "75vh"
    toggle.setAttribute("aria-pressed", String(large))
    toggle.textContent = large ? "標準高さに戻す" : "大きく表示"
    status.textContent = large ? "大きく表示しています" : "標準高さで表示しています"
    writeLarge(large)
  }

  const toggleHeight = () => {
    applyHeight(toggle.getAttribute("aria-pressed") !== "true")
  }

  toggle.addEventListener("click", toggleHeight)

  document.addEventListener("keydown", (event) => {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || isEditableTarget(event.target)) return
    if (event.key !== "h" && event.key !== "H") return

    event.preventDefault()
    toggleHeight()
  })

  applyHeight(readLarge())
}

export function setupPdfPreviewTools() {
  document.querySelectorAll("[data-pdf-preview-tools]").forEach(setupPdfPreview)
}
