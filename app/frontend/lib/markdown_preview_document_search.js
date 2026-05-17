const SEARCH_MARK_CLASS = "portal-document-search-mark"
const CURRENT_MARK_CLASS = "is-current"

function injectDocumentSearchStyle(frameDocument) {
  if (frameDocument.querySelector("style[data-docs-portal-document-search]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalDocumentSearch = "true"
  style.textContent = `
    .portal-document-search-bar {
      position: sticky;
      top: .75rem;
      z-index: 20;
      display: flex;
      gap: .45rem;
      align-items: center;
      flex-wrap: wrap;
      margin: .75rem 0 1rem;
      padding: .55rem .7rem;
      border: 1px solid var(--doc-border-soft, #eef2f7);
      border-radius: 999px;
      background: rgb(255 255 255 / 92%);
      box-shadow: 0 10px 24px rgb(15 23 42 / 10%);
    }
    .portal-document-search-bar.is-collapsed {
      display: inline-flex;
      padding: .2rem;
    }
    .portal-document-search-bar.is-collapsed .portal-document-search-controls {
      display: none;
    }
    .portal-document-search-toggle {
      border: 1px solid var(--doc-primary-border, #bfdbfe);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: var(--doc-primary, #2563eb);
      cursor: pointer;
      font: inherit;
      font-size: .78rem;
      font-weight: 700;
      line-height: 1.2;
      padding: .25rem .65rem;
      white-space: nowrap;
    }
    .portal-document-search-toggle:hover,
    .portal-document-search-toggle:focus {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
    }
    .portal-document-search-controls {
      display: inline-flex;
      gap: .45rem;
      align-items: center;
      flex-wrap: wrap;
    }
    .portal-document-search-bar label {
      display: inline-flex;
      gap: .45rem;
      align-items: center;
      margin: 0;
      color: var(--doc-text-muted, #64748b);
      font-size: .78rem;
      font-weight: 700;
      white-space: nowrap;
    }
    .portal-document-search-shortcut {
      border: 1px solid var(--doc-border, #dbe3ef);
      border-radius: 6px;
      background: var(--doc-bg-soft, #f8fafc);
      color: var(--doc-text-muted, #64748b);
      font-size: .7rem;
      font-weight: 700;
      padding: .05rem .32rem;
    }
    .portal-document-search-bar input[type="search"] {
      width: 220px;
      border: 1px solid var(--doc-border, #dbe3ef);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: inherit;
      font: inherit;
      font-size: .8rem;
      padding: .27rem .7rem;
    }
    .portal-document-search-bar input[type="search"]:focus {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
      box-shadow: 0 0 0 3px rgb(37 99 235 / 14%);
    }
    .portal-document-search-button {
      border: 1px solid var(--doc-primary-border, #bfdbfe);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: var(--doc-primary, #2563eb);
      cursor: pointer;
      font: inherit;
      font-size: .78rem;
      padding: .25rem .58rem;
    }
    .portal-document-search-button:hover,
    .portal-document-search-button:focus {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
    }
    .portal-document-search-count {
      min-width: 4.5rem;
      color: var(--doc-text-muted, #64748b);
      font-size: .78rem;
      white-space: nowrap;
    }
    .portal-document-search-mark {
      background: #fff7cc;
      border-radius: 3px;
      box-shadow: 0 0 0 1px #f59e0b inset;
      padding: 0 .05em;
    }
    .portal-document-search-mark.is-current {
      background: #fed7aa;
      box-shadow: 0 0 0 2px #ea580c inset;
    }
    @media (max-width: 720px) {
      .portal-document-search-bar {
        align-items: flex-start;
        border-radius: 14px;
        flex-direction: column;
      }
      .portal-document-search-bar.is-collapsed {
        border-radius: 999px;
      }
      .portal-document-search-controls {
        align-items: flex-start;
        flex-direction: column;
      }
      .portal-document-search-bar input[type="search"] {
        width: 190px;
      }
    }
  `
  frameDocument.head?.appendChild(style)
}

function searchRoot(frameDocument) {
  return frameDocument.querySelector("main article") ||
    frameDocument.querySelector("article") ||
    frameDocument.querySelector(".markdown") ||
    frameDocument.querySelector(".theme-doc-markdown") ||
    frameDocument.body
}

function clearMarks(root) {
  root.querySelectorAll(`.${SEARCH_MARK_CLASS}`).forEach((mark) => {
    const text = mark.ownerDocument.createTextNode(mark.textContent || "")
    mark.replaceWith(text)
  })
  root.normalize()
}

function textNodes(root) {
  const walker = root.ownerDocument.createTreeWalker(
    root,
    NodeFilter.SHOW_TEXT,
    {
      acceptNode: (node) => {
        if (!node.nodeValue?.trim()) return NodeFilter.FILTER_REJECT
        const parent = node.parentElement
        if (!parent) return NodeFilter.FILTER_REJECT
        if (parent.closest("script, style, nav, footer, aside, .portal-document-search-bar")) return NodeFilter.FILTER_REJECT
        return NodeFilter.FILTER_ACCEPT
      }
    }
  )

  const nodes = []
  while (walker.nextNode()) nodes.push(walker.currentNode)
  return nodes
}

function highlightTextNode(frameDocument, node, query) {
  const text = node.nodeValue || ""
  const lowerText = text.toLowerCase()
  const lowerQuery = query.toLowerCase()
  const fragment = frameDocument.createDocumentFragment()
  let cursor = 0
  let count = 0

  while (cursor < text.length) {
    const index = lowerText.indexOf(lowerQuery, cursor)
    if (index === -1) break

    if (index > cursor) fragment.appendChild(frameDocument.createTextNode(text.slice(cursor, index)))

    const mark = frameDocument.createElement("mark")
    mark.className = SEARCH_MARK_CLASS
    mark.textContent = text.slice(index, index + query.length)
    fragment.appendChild(mark)

    cursor = index + query.length
    count += 1
  }

  if (count === 0) return 0
  if (cursor < text.length) fragment.appendChild(frameDocument.createTextNode(text.slice(cursor)))
  node.replaceWith(fragment)
  return count
}

function currentMarks(root) {
  return Array.from(root.querySelectorAll(`.${SEARCH_MARK_CLASS}`))
}

function setCurrentMark(marks, index) {
  marks.forEach((mark) => mark.classList.remove(CURRENT_MARK_CLASS))
  const current = marks[index]
  if (!current) return

  current.classList.add(CURRENT_MARK_CLASS)
  current.scrollIntoView({ block: "center", behavior: "smooth" })
}

function updateSearch(frameDocument, root, input, count, state) {
  clearMarks(root)
  state.currentIndex = 0

  const query = input.value.trim()
  if (query.length < 2) {
    count.textContent = query.length > 0 ? "2文字以上" : ""
    return
  }

  let matchCount = 0
  textNodes(root).forEach((node) => {
    matchCount += highlightTextNode(frameDocument, node, query)
  })

  const marks = currentMarks(root)
  if (marks.length > 0) setCurrentMark(marks, 0)
  count.textContent = `${matchCount}件`
}

function moveCurrent(root, count, state, direction) {
  const marks = currentMarks(root)
  if (marks.length === 0) return

  state.currentIndex = (state.currentIndex + direction + marks.length) % marks.length
  setCurrentMark(marks, state.currentIndex)
  count.textContent = `${state.currentIndex + 1}/${marks.length}`
}

function clearSearch(root, input, count, state) {
  input.value = ""
  clearMarks(root)
  count.textContent = ""
  state.currentIndex = 0
}

function expandSearchBar(bar, input, toggleButton) {
  bar.classList.remove("is-collapsed")
  toggleButton.setAttribute("aria-expanded", "true")
  toggleButton.textContent = "検索を閉じる"
  input.focus()
  input.select()
}

function collapseSearchBar(bar, input, toggleButton) {
  bar.classList.add("is-collapsed")
  toggleButton.setAttribute("aria-expanded", "false")
  toggleButton.textContent = "文書内検索 /"
  input.blur()
}

function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function setupSearchShortcuts(frameDocument, root, bar, input, count, state, toggleButton) {
  frameDocument.addEventListener("keydown", (event) => {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return

    if (event.key === "/" && !isEditableTarget(event.target)) {
      event.preventDefault()
      expandSearchBar(bar, input, toggleButton)
      return
    }

    if (event.key === "Escape" && frameDocument.activeElement === input) {
      event.preventDefault()
      clearSearch(root, input, count, state)
      collapseSearchBar(bar, input, toggleButton)
      return
    }

    if (event.key === "Enter" && frameDocument.activeElement === input) {
      event.preventDefault()
      moveCurrent(root, count, state, event.shiftKey ? -1 : 1)
    }
  })
}

function enhanceDocumentSearchInFrame(frame) {
  const frameDocument = frame.contentDocument
  if (!frameDocument?.body) return
  if (frameDocument.body.dataset.documentSearchReady === "true") return

  const root = searchRoot(frameDocument)
  if (!root) return

  frameDocument.body.dataset.documentSearchReady = "true"
  injectDocumentSearchStyle(frameDocument)

  const bar = frameDocument.createElement("div")
  bar.className = "portal-document-search-bar is-collapsed"

  const toggleButton = frameDocument.createElement("button")
  toggleButton.type = "button"
  toggleButton.className = "portal-document-search-toggle"
  toggleButton.textContent = "文書内検索 /"
  toggleButton.setAttribute("aria-expanded", "false")

  const controls = frameDocument.createElement("div")
  controls.className = "portal-document-search-controls"

  const label = frameDocument.createElement("label")
  label.textContent = "この文書内を検索"

  const shortcut = frameDocument.createElement("span")
  shortcut.className = "portal-document-search-shortcut"
  shortcut.textContent = "/"
  shortcut.setAttribute("aria-hidden", "true")

  const input = frameDocument.createElement("input")
  input.type = "search"
  input.placeholder = "キーワード"
  input.setAttribute("aria-label", "この文書内を検索")

  const previousButton = frameDocument.createElement("button")
  previousButton.type = "button"
  previousButton.className = "portal-document-search-button"
  previousButton.textContent = "前へ"

  const nextButton = frameDocument.createElement("button")
  nextButton.type = "button"
  nextButton.className = "portal-document-search-button"
  nextButton.textContent = "次へ"

  const clearButton = frameDocument.createElement("button")
  clearButton.type = "button"
  clearButton.className = "portal-document-search-button"
  clearButton.textContent = "クリア"

  const count = frameDocument.createElement("span")
  count.className = "portal-document-search-count"
  count.setAttribute("aria-live", "polite")

  const state = { currentIndex: 0 }

  label.appendChild(shortcut)
  label.appendChild(input)
  controls.appendChild(label)
  controls.appendChild(previousButton)
  controls.appendChild(nextButton)
  controls.appendChild(clearButton)
  controls.appendChild(count)
  bar.appendChild(toggleButton)
  bar.appendChild(controls)
  root.insertBefore(bar, root.firstChild)

  toggleButton.addEventListener("click", () => {
    if (bar.classList.contains("is-collapsed")) {
      expandSearchBar(bar, input, toggleButton)
    } else {
      clearSearch(root, input, count, state)
      collapseSearchBar(bar, input, toggleButton)
    }
  })
  input.addEventListener("input", () => updateSearch(frameDocument, root, input, count, state))
  input.addEventListener("search", () => {
    if (input.value === "") clearSearch(root, input, count, state)
  })
  previousButton.addEventListener("click", () => moveCurrent(root, count, state, -1))
  nextButton.addEventListener("click", () => moveCurrent(root, count, state, 1))
  clearButton.addEventListener("click", () => {
    clearSearch(root, input, count, state)
    input.focus()
  })
  setupSearchShortcuts(frameDocument, root, bar, input, count, state, toggleButton)
}

export function setupMarkdownPreviewDocumentSearch() {
  document.querySelectorAll("iframe.site-viewer-frame").forEach((frame) => {
    if (frame.dataset.documentSearchListenerReady !== "true") {
      frame.dataset.documentSearchListenerReady = "true"
      frame.addEventListener("load", () => {
        try {
          enhanceDocumentSearchInFrame(frame)
        } catch (_error) {
          // Cross-origin fallback: keep the viewer usable even if document search cannot be injected.
        }
      })
    }

    try {
      enhanceDocumentSearchInFrame(frame)
    } catch (_error) {
      // Cross-origin fallback: keep the viewer usable even if document search cannot be injected.
    }
  })
}
