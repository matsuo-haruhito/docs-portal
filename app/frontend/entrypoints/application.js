import "@hotwired/turbo-rails"

const STORAGE_KEY = "docsPortal.sidebar"
const DEFAULT_WIDTH = 360
const MIN_WIDTH = 260
const MAX_WIDTH = 720

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

function expandTreeFolderForNavigation(link) {
  if (link.dataset.treeItemType !== "document_tree_folder") return

  const row = link.closest("tr")
  const toggle = row?.querySelector(".tree-toggle__action[aria-expanded='false']")
  if (!toggle) return

  toggle.click()
}

function setupTreeNavigation() {
  document.addEventListener("click", (event) => {
    const link = event.target.closest("a[data-tree-nav-link='true']")
    if (!link) return

    expandTreeFolderForNavigation(link)
  })
}

setupTreeNavigation()

document.addEventListener("turbo:load", setupSidebars)
document.addEventListener("turbo:render", setupSidebars)
