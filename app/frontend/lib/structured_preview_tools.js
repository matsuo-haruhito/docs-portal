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
    .structured-preview-line.is-structured-preview-match {
      background: #fff7cc;
      box-shadow: inset 4px 0 0 #f59e0b;
    }
  `
  document.head?.appendChild(style)
}

function lineText(line) {
  return (line.textContent || "").toLowerCase()
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
  const copyButton = container.querySelector("[data-structured-preview-copy]")
  const count = container.querySelector("[data-structured-preview-count]")
  const status = container.querySelector("[data-structured-preview-status]")
  const code = container.querySelector("[data-structured-preview-code]")
  if (!input || !clearButton || !copyButton || !count || !status || !code) return

  const lines = prepareCodeLines(code)

  const updateSearch = () => {
    const query = input.value.trim().toLowerCase()
    let matchedCount = 0

    lines.forEach((line) => {
      const matched = query.length > 0 && lineText(line).includes(query)
      line.classList.toggle("is-structured-preview-match", matched)
      if (matched) matchedCount += 1
    })

    count.textContent = query.length === 0 ? `${lines.length}行` : `${matchedCount}/${lines.length}行`
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
      await navigator.clipboard.writeText(lines.map((line) => line.textContent || "").join("\n"))
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

export function setupStructuredPreviewTools() {
  document.querySelectorAll("[data-structured-preview-tools]").forEach(setupStructuredPreview)
}
