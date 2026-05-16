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

async function copyCodeText(codeElement, status) {
  const text = codeElement.textContent || ""

  try {
    await navigator.clipboard.writeText(text)
    status.textContent = "コピーしました"
  } catch (_error) {
    status.textContent = "コピーできませんでした"
  }

  window.setTimeout(() => {
    status.textContent = ""
  }, 1800)
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

    const wrapper = frameDocument.createElement("div")
    wrapper.className = "portal-codeblock-frame"
    wrapper.dataset.codeblockIndex = String(index + 1)

    const toolbar = frameDocument.createElement("div")
    toolbar.className = "portal-codeblock-toolbar"

    const language = frameDocument.createElement("span")
    language.className = "portal-codeblock-language"
    language.textContent = detectCodeLanguage(codeElement)

    const warning = frameDocument.createElement("span")
    warning.className = "portal-codeblock-warning"
    warning.textContent = "機密注意"
    warning.hidden = !includesSensitiveKeyword(codeElement.textContent || "")

    const copyButton = frameDocument.createElement("button")
    copyButton.type = "button"
    copyButton.className = "portal-codeblock-button"
    copyButton.textContent = "コピー"
    copyButton.setAttribute("aria-label", "コードブロックをコピー")

    const status = frameDocument.createElement("span")
    status.className = "portal-codeblock-status"
    status.setAttribute("aria-live", "polite")

    toolbar.appendChild(language)
    toolbar.appendChild(warning)
    toolbar.appendChild(copyButton)
    toolbar.appendChild(status)

    pre.parentNode.insertBefore(wrapper, pre)
    wrapper.appendChild(pre)
    wrapper.appendChild(toolbar)

    copyButton.addEventListener("click", () => copyCodeText(codeElement, status))
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
