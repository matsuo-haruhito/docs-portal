function injectCodeblockToolStyle(frameDocument) {
  if (frameDocument.querySelector("style[data-docs-portal-codeblock-tools]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalCodeblockTools = "true"
  style.textContent = `
    .portal-codeblock-frame {
      position: relative;
    }
    .portal-codeblock-toolbar {
      position: absolute;
      top: .45rem;
      right: .45rem;
      z-index: 5;
      display: inline-flex;
      gap: .35rem;
      align-items: center;
      padding: .2rem;
      border: 1px solid var(--doc-border-soft, #eef2f7);
      border-radius: 999px;
      background: rgb(255 255 255 / 86%);
      box-shadow: 0 8px 20px rgb(15 23 42 / 10%);
    }
    .portal-codeblock-language,
    .portal-codeblock-warning {
      border-radius: 999px;
      font-size: .72rem;
      line-height: 1.2;
      padding: .2rem .48rem;
      white-space: nowrap;
    }
    .portal-codeblock-language {
      background: var(--doc-bg-soft, #f8fafc);
      color: var(--doc-text-muted, #64748b);
      font-weight: 700;
    }
    .portal-codeblock-warning {
      background: #fff7ed;
      color: #c2410c;
      font-weight: 700;
    }
    .portal-codeblock-button {
      border: 1px solid var(--doc-primary-border, #bfdbfe);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: var(--doc-primary, #2563eb);
      cursor: pointer;
      font: inherit;
      font-size: .74rem;
      line-height: 1.2;
      padding: .22rem .55rem;
    }
    .portal-codeblock-button:hover,
    .portal-codeblock-button:focus {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
    }
    .portal-codeblock-status {
      min-width: 4.5rem;
      color: var(--doc-text-muted, #64748b);
      font-size: .72rem;
      white-space: nowrap;
    }
    .portal-codeblock-frame pre {
      padding-top: 2.4rem !important;
    }
    .portal-codeblock-lines {
      display: grid;
      grid-template-columns: max-content minmax(0, 1fr);
      column-gap: .8rem;
    }
    .portal-codeblock-line-number {
      color: var(--doc-text-muted, #94a3b8);
      font-variant-numeric: tabular-nums;
      padding-left: .2rem;
      text-align: right;
      user-select: none;
    }
    .portal-codeblock-line-number a {
      color: inherit;
      text-decoration: none;
    }
    .portal-codeblock-line-number a:hover,
    .portal-codeblock-line-number a:focus {
      color: var(--doc-primary, #2563eb);
      outline: none;
      text-decoration: underline;
    }
    .portal-codeblock-line {
      min-width: 0;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .portal-codeblock-line:target {
      background: #fff7cc;
      outline: 2px solid #f59e0b;
      outline-offset: 2px;
    }
  `
  frameDocument.head?.appendChild(style)
}

function detectCodeLanguage(codeElement) {
  const className = codeElement.className || codeElement.closest("pre")?.className || ""
  const match = className.match(/(?:language|lang)-([a-z0-9_+-]+)/i)
  return match?.[1]?.toLowerCase() || "code"
}

function includesSensitiveKeyword(text) {
  return /\b(secret|token|password|passwd|authorization|api[_-]?key|access[_-]?key|client[_-]?secret|bearer)\b/i.test(text)
}

function addLineAnchors(frameDocument, codeElement, blockId) {
  if (codeElement.dataset.lineAnchorsReady === "true") return

  const text = codeElement.textContent || ""
  const lines = text.split("\n")
  if (lines.length <= 1) return

  codeElement.dataset.lineAnchorsReady = "true"
  codeElement.textContent = ""
  codeElement.classList.add("portal-codeblock-lines")

  lines.forEach((line, lineIndex) => {
    const lineNumber = lineIndex + 1
    const lineId = `${blockId}-L${lineNumber}`

    const number = frameDocument.createElement("span")
    number.className = "portal-codeblock-line-number"

    const anchor = frameDocument.createElement("a")
    anchor.href = `#${lineId}`
    anchor.textContent = String(lineNumber)
    anchor.setAttribute("aria-label", `${lineNumber}行目へのリンク`)
    number.appendChild(anchor)

    const content = frameDocument.createElement("span")
    content.className = "portal-codeblock-line"
    content.id = lineId
    content.textContent = line.length > 0 ? line : " "

    codeElement.appendChild(number)
    codeElement.appendChild(content)
  })
}

function codeText(codeElement) {
  const lineElements = Array.from(codeElement.querySelectorAll(".portal-codeblock-line"))
  if (lineElements.length === 0) return codeElement.textContent || ""

  return lineElements
    .map((line) => line.textContent === " " ? "" : line.textContent)
    .join("\n")
}

function clearStatusLater(status, timeout = 1800) {
  window.setTimeout(() => {
    status.textContent = ""
  }, timeout)
}

async function copyText(text, status, successMessage = "コピーしました") {
  try {
    await navigator.clipboard.writeText(text)
    status.textContent = successMessage
  } catch (_error) {
    status.textContent = "コピーできませんでした"
  }

  clearStatusLater(status)
}

async function copyCodeText(codeElement, status) {
  await copyText(codeText(codeElement), status)
}

async function copyFormattedJsonCode(codeElement, status) {
  try {
    const parsed = JSON.parse(codeText(codeElement))
    await copyText(JSON.stringify(parsed, null, 2), status, "整形コピーしました")
  } catch (error) {
    status.textContent = `JSONエラー: ${error.message}`
    clearStatusLater(status, 3200)
  }
}

function validateJsonCode(codeElement, status) {
  try {
    JSON.parse(codeText(codeElement))
    status.textContent = "JSON OK"
  } catch (error) {
    status.textContent = `JSONエラー: ${error.message}`
  }

  clearStatusLater(status, 3200)
}

function enhanceCodeblocksInFrame(frame) {
  const frameDocument = frame.contentDocument
  if (!frameDocument?.body) return

  injectCodeblockToolStyle(frameDocument)

  const codeblocks = Array.from(frameDocument.querySelectorAll("pre > code"))
    .filter((codeElement) => !codeElement.closest(".portal-codeblock-frame"))

  codeblocks.forEach((codeElement, index) => {
    const pre = codeElement.closest("pre")
    if (!pre) return

    const blockId = `codeblock-${index + 1}`
    const wrapper = frameDocument.createElement("div")
    wrapper.className = "portal-codeblock-frame"
    wrapper.dataset.codeblockIndex = String(index + 1)
    wrapper.id = blockId

    const toolbar = frameDocument.createElement("div")
    toolbar.className = "portal-codeblock-toolbar"

    const detectedLanguage = detectCodeLanguage(codeElement)
    const isJson = detectedLanguage === "json"
    const language = frameDocument.createElement("span")
    language.className = "portal-codeblock-language"
    language.textContent = detectedLanguage

    const warning = frameDocument.createElement("span")
    warning.className = "portal-codeblock-warning"
    warning.textContent = "機密注意"
    warning.hidden = !includesSensitiveKeyword(codeElement.textContent || "")

    const copyButton = frameDocument.createElement("button")
    copyButton.type = "button"
    copyButton.className = "portal-codeblock-button"
    copyButton.textContent = "コピー"
    copyButton.setAttribute("aria-label", "コードブロックをコピー")

    const formatJsonButton = frameDocument.createElement("button")
    formatJsonButton.type = "button"
    formatJsonButton.className = "portal-codeblock-button"
    formatJsonButton.textContent = "JSON整形コピー"
    formatJsonButton.setAttribute("aria-label", "JSONを整形してコピー")
    formatJsonButton.hidden = !isJson

    const validateJsonButton = frameDocument.createElement("button")
    validateJsonButton.type = "button"
    validateJsonButton.className = "portal-codeblock-button"
    validateJsonButton.textContent = "JSON検証"
    validateJsonButton.setAttribute("aria-label", "JSON構文を検証")
    validateJsonButton.hidden = !isJson

    const status = frameDocument.createElement("span")
    status.className = "portal-codeblock-status"
    status.setAttribute("aria-live", "polite")

    toolbar.appendChild(language)
    toolbar.appendChild(warning)
    toolbar.appendChild(copyButton)
    toolbar.appendChild(formatJsonButton)
    toolbar.appendChild(validateJsonButton)
    toolbar.appendChild(status)

    pre.parentNode.insertBefore(wrapper, pre)
    wrapper.appendChild(pre)
    wrapper.appendChild(toolbar)
    addLineAnchors(frameDocument, codeElement, blockId)

    copyButton.addEventListener("click", () => copyCodeText(codeElement, status))
    formatJsonButton.addEventListener("click", () => copyFormattedJsonCode(codeElement, status))
    validateJsonButton.addEventListener("click", () => validateJsonCode(codeElement, status))
  })
}

export function setupMarkdownPreviewCodeblockTools() {
  document.querySelectorAll("iframe.site-viewer-frame").forEach((frame) => {
    if (frame.dataset.codeblockToolsListenerReady !== "true") {
      frame.dataset.codeblockToolsListenerReady = "true"
      frame.addEventListener("load", () => {
        try {
          enhanceCodeblocksInFrame(frame)
        } catch (_error) {
          // Cross-origin fallback: keep the viewer usable even if codeblock tools cannot be injected.
        }
      })
    }

    try {
      enhanceCodeblocksInFrame(frame)
    } catch (_error) {
      // Cross-origin fallback: keep the viewer usable even if codeblock tools cannot be injected.
    }
  })
}
