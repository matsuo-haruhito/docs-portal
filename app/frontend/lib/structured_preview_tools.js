function setupStructuredPreview(container) {
  if (container.dataset.structuredPreviewToolsReady === "true") return
  container.dataset.structuredPreviewToolsReady = "true"

  const copyButton = container.querySelector("[data-structured-preview-copy]")
  const status = container.querySelector("[data-structured-preview-status]")
  const code = container.querySelector("[data-structured-preview-code]")
  if (!copyButton || !status || !code) return

  copyButton.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(code.textContent || "")
      status.textContent = "コピーしました"
    } catch (_error) {
      status.textContent = "コピーできませんでした"
    }

    window.setTimeout(() => {
      status.textContent = ""
    }, 1800)
  })
}

export function setupStructuredPreviewTools() {
  document.querySelectorAll("[data-structured-preview-tools]").forEach(setupStructuredPreview)
}
