import "@hotwired/turbo-rails"
import "tom-select/dist/css/tom-select.css"
import { setupTomSelectFields } from "../lib/tom_select_fields"

const STORAGE_KEY = "docsPortal.sidebar"
const DEFAULT_WIDTH = 360
const MIN_WIDTH = 260
const MAX_WIDTH = 720
const TABLE_WIDTH_STORAGE_PREFIX = "docsPortal.previewTableWidth"

function clampWidth(value) {
  return Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, value))
}

function readState() {
  try {
    return JSON.parse(window.localStorage.getItem(STORAGE_KEY) || "{}")
  } catch (_error) {
    return {}
  }
}

function writeState(nextState) {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...readState(), ...nextState }))
}

function applyCollapsedState(layout, toggle, collapsed) {
  layout.classList.toggle("is-sidebar-collapsed", collapsed)
  toggle.setAttribute("aria-expanded", String(!collapsed))
  toggle.setAttribute("aria-label", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
  toggle.setAttribute("title", collapsed ? "文書ツリーを開く" : "文書ツリーを折りたたむ")
  toggle.textContent = collapsed ? "▶" : "◀"
}

function setupSidebar(layout) {
  if (layout.dataset.sidebarReady === "true") return
  layout.dataset.sidebarReady = "true"

  const sidebar = layout.querySelector("[data-docs-sidebar]")
  const toggle = layout.querySelector("[data-sidebar-toggle]")
  const resizer = layout.querySelector("[data-sidebar-resizer]")
  if (!sidebar || !toggle || !resizer) return

  const storedState = readState()
  const initialWidth = clampWidth(Number(storedState.width) || DEFAULT_WIDTH)
  layout.style.setProperty("--sidebar-width", `${initialWidth}px`)
  applyCollapsedState(layout, toggle, storedState.collapsed === true)

  toggle.addEventListener("click", () => {
    const collapsed = !layout.classList.contains("is-sidebar-collapsed")
    applyCollapsedState(layout, toggle, collapsed)
    writeState({ collapsed })
  })

  let dragging = false
  let startX = 0
  let startWidth = initialWidth

  const stopDragging = () => {
    if (!dragging) return
    dragging = false
    document.body.classList.remove("is-sidebar-resizing")
    sidebar.classList.remove("is-resizing")
  }

  const resizeTo = (clientX) => {
    const nextWidth = clampWidth(startWidth + clientX - startX)
    layout.style.setProperty("--sidebar-width", `${nextWidth}px`)
    writeState({ width: nextWidth, collapsed: false })
  }

  resizer.addEventListener("pointerdown", (event) => {
    if (layout.classList.contains("is-sidebar-collapsed")) return
    dragging = true
    startX = event.clientX
    startWidth = sidebar.getBoundingClientRect().width
    document.body.classList.add("is-sidebar-resizing")
    sidebar.classList.add("is-resizing")
    resizer.setPointerCapture(event.pointerId)
    event.preventDefault()
  })

  resizer.addEventListener("pointermove", (event) => {
    if (!dragging) return
    resizeTo(event.clientX)
  })

  resizer.addEventListener("pointerup", stopDragging)
  resizer.addEventListener("pointercancel", stopDragging)

  resizer.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const currentWidth = sidebar.getBoundingClientRect().width
    const step = event.shiftKey ? 40 : 16
    const nextWidth = event.key === "Home" ? MIN_WIDTH :
      event.key === "End" ? MAX_WIDTH :
      event.key === "ArrowLeft" ? currentWidth - step : currentWidth + step
    const width = clampWidth(nextWidth)
    layout.classList.remove("is-sidebar-collapsed")
    applyCollapsedState(layout, toggle, false)
    layout.style.setProperty("--sidebar-width", `${width}px`)
    writeState({ width, collapsed: false })
  })
}

function setupSidebars() {
  document.querySelectorAll("[data-sidebar-layout]").forEach(setupSidebar)
}

function closeOtherNavDropdowns(currentDropdown) {
  document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
    if (dropdown !== currentDropdown) dropdown.open = false
  })
}

function setupNavDropdowns() {
  if (document.documentElement.dataset.navDropdownsReady === "true") return
  document.documentElement.dataset.navDropdownsReady = "true"

  document.addEventListener("toggle", (event) => {
    const dropdown = event.target.closest?.("[data-nav-dropdown]")
    if (!dropdown || !dropdown.open) return
    closeOtherNavDropdowns(dropdown)
  }, true)

  document.addEventListener("click", (event) => {
    const clickedDropdown = event.target.closest("[data-nav-dropdown]")
    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      if (dropdown !== clickedDropdown) dropdown.open = false
    })
  })

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return
    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      dropdown.open = false
    })
  })
}

function navigateMainPanel(url) {
  const frame = document.getElementById("main_panel")
  if (!frame) return false

  frame.src = url
  return true
}

function refreshDocumentTree(link) {
  const url = link.dataset.treeRefreshUrl
  if (!url) return

  fetch(url, {
    headers: {
      Accept: "text/vnd.turbo-stream.html"
    },
    credentials: "same-origin"
  })
    .then((response) => response.ok ? response.text() : "")
    .then((html) => {
      if (!html) return
      window.Turbo?.renderStreamMessage(html)
    })
}

function setupDocumentTreeNavigation() {
  document.addEventListener("click", (event) => {
    if (event.target.closest(".tree-toggle")) return

    const link = event.target.closest("a[data-tree-nav-link='true']")
    if (!link) return
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return

    event.preventDefault()
    if (!navigateMainPanel(link.href)) return

    refreshDocumentTree(link)
  }, true)
}

function tableWidthStorageKey(frame, index) {
  const url = frame.getAttribute("src") || frame.dataset.tableWidthSrc || window.location.pathname
  return `${TABLE_WIDTH_STORAGE_PREFIX}:${url}:table:${index}`
}

function readTableWidth(frame, index) {
  const value = Number(window.localStorage.getItem(tableWidthStorageKey(frame, index)))
  return Number.isFinite(value) && value >= 80 && value <= 220 ? value : 100
}

function writeTableWidth(frame, index, value) {
  window.localStorage.setItem(tableWidthStorageKey(frame, index), String(value))
}

function injectTableWidthStyle(frameDocument) {
  if (frameDocument.querySelector("style[data-docs-portal-table-width]")) return

  const style = frameDocument.createElement("style")
  style.dataset.docsPortalTableWidth = "true"
  style.textContent = `
    .portal-table-width-frame {
      margin: 1rem 0;
      border: 1px solid var(--doc-border, #e5e7eb);
      border-radius: 12px;
      background: var(--doc-surface, #fff);
      overflow: hidden;
    }
    .portal-table-width-toolbar {
      display: flex;
      gap: .55rem;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      padding: .55rem .75rem;
      border-bottom: 1px solid var(--doc-border-soft, #eef2f7);
      background: var(--doc-bg-soft, #f8fafc);
      color: var(--doc-text-muted, #64748b);
      font-size: .82rem;
    }
    .portal-table-width-toolbar label {
      display: inline-flex;
      gap: .45rem;
      align-items: center;
      margin: 0;
      white-space: nowrap;
    }
    .portal-table-width-toolbar input[type="range"] {
      width: 160px;
      accent-color: var(--doc-primary, #2563eb);
    }
    .portal-table-width-actions {
      display: inline-flex;
      gap: .35rem;
      align-items: center;
    }
    .portal-table-width-button {
      border: 1px solid var(--doc-primary-border, #bfdbfe);
      border-radius: 999px;
      background: var(--doc-surface, #fff);
      color: var(--doc-primary, #2563eb);
      cursor: pointer;
      font: inherit;
      font-size: .78rem;
      padding: .24rem .58rem;
    }
    .portal-table-width-button:hover,
    .portal-table-width-button:focus {
      border-color: var(--doc-primary, #2563eb);
      outline: none;
    }
    .portal-table-width-scroll {
      overflow-x: auto;
      padding: .65rem;
    }
    .portal-table-width-frame table {
      margin: 0 !important;
      width: var(--portal-table-width, 100%) !important;
      min-width: var(--portal-table-width, 100%) !important;
      max-width: none !important;
      display: table !important;
    }
    @media (max-width: 720px) {
      .portal-table-width-toolbar {
        align-items: flex-start;
        flex-direction: column;
      }
      .portal-table-width-toolbar input[type="range"] {
        width: 190px;
      }
    }
  `
  frameDocument.head?.appendChild(style)
}

function enhancePreviewTables(frame) {
  const frameDocument = frame.contentDocument
  if (!frameDocument?.body) return

  injectTableWidthStyle(frameDocument)

  const tables = Array.from(frameDocument.querySelectorAll(".markdown table, .theme-doc-markdown table, article table"))
    .filter((table) => !table.closest(".portal-table-width-frame"))

  tables.forEach((table, index) => {
    const width = readTableWidth(frame, index)
    const wrapper = frameDocument.createElement("div")
    wrapper.className = "portal-table-width-frame"
    wrapper.style.setProperty("--portal-table-width", `${width}%`)

    const toolbar = frameDocument.createElement("div")
    toolbar.className = "portal-table-width-toolbar"

    const label = frameDocument.createElement("label")
    label.textContent = "表の幅"

    const range = frameDocument.createElement("input")
    range.type = "range"
    range.min = "80"
    range.max = "220"
    range.step = "10"
    range.value = String(width)

    const valueText = frameDocument.createElement("span")
    valueText.textContent = `${width}%`

    label.appendChild(range)
    label.appendChild(valueText)

    const actions = frameDocument.createElement("span")
    actions.className = "portal-table-width-actions"

    const fitButton = frameDocument.createElement("button")
    fitButton.type = "button"
    fitButton.className = "portal-table-width-button"
    fitButton.textContent = "標準"

    const wideButton = frameDocument.createElement("button")
    wideButton.type = "button"
    wideButton.className = "portal-table-width-button"
    wideButton.textContent = "広め"

    actions.appendChild(fitButton)
    actions.appendChild(wideButton)
    toolbar.appendChild(label)
    toolbar.appendChild(actions)

    const scroll = frameDocument.createElement("div")
    scroll.className = "portal-table-width-scroll"

    table.parentNode.insertBefore(wrapper, table)
    scroll.appendChild(table)
    wrapper.appendChild(toolbar)
    wrapper.appendChild(scroll)

    const applyWidth = (nextWidth) => {
      wrapper.style.setProperty("--portal-table-width", `${nextWidth}%`)
      range.value = String(nextWidth)
      valueText.textContent = `${nextWidth}%`
      writeTableWidth(frame, index, nextWidth)
    }

    range.addEventListener("input", () => applyWidth(Number(range.value)))
    fitButton.addEventListener("click", () => applyWidth(100))
    wideButton.addEventListener("click", () => applyWidth(160))
  })
}

function setupPreviewTableResizers() {
  document.querySelectorAll("iframe.site-viewer-frame").forEach((frame) => {
    if (frame.dataset.tableWidthReady === "true") return
    frame.dataset.tableWidthReady = "true"

    const enhance = () => {
      try {
        enhancePreviewTables(frame)
      } catch (_error) {
        // Cross-origin fallback: if the preview ever becomes external, keep the viewer usable.
      }
    }

    frame.addEventListener("load", enhance)
    if (frame.contentDocument?.readyState === "complete") enhance()
  })
}

setupNavDropdowns()
setupDocumentTreeNavigation()

document.addEventListener("turbo:load", () => {
  setupSidebars()
  setupPreviewTableResizers()
  setupTomSelectFields()
})
document.addEventListener("turbo:render", () => {
  setupSidebars()
  setupPreviewTableResizers()
  setupTomSelectFields()
})
