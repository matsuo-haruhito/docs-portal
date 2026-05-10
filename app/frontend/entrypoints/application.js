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

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content
}

function shouldHandleAsPlainLeftClick(event) {
  return event.button === 0 &&
    !event.metaKey &&
    !event.ctrlKey &&
    !event.shiftKey &&
    !event.altKey
}

async function refreshTreeFromLink(link) {
  const url = link.dataset.treeOpenUrl || link.dataset.treeRefreshUrl
  if (!url) return

  const response = await fetch(url, {
    method: "GET",
    headers: {
      Accept: "text/vnd.turbo-stream.html",
      "X-CSRF-Token": csrfToken() || ""
    },
    credentials: "same-origin"
  })

  if (!response.ok) return

  const html = await response.text()
  if (html.trim()) window.Turbo?.renderStreamMessage(html)
}

function setupTreeNavigation() {
  if (document.documentElement.dataset.treeNavigationReady === "true") return
  document.documentElement.dataset.treeNavigationReady = "true"

  document.addEventListener("click", async (event) => {
    const link = event.target.closest?.("a[data-tree-nav-link='true']")
    if (!link || event.defaultPrevented || !shouldHandleAsPlainLeftClick(event)) return
    if (link.target && link.target !== "_self") return

    const destination = link.href
    if (!destination) return

    event.preventDefault()

    try {
      await refreshTreeFromLink(link)
    } catch (_error) {
      // Tree refresh is best-effort. Navigation should still proceed.
    }

    window.Turbo?.visit(destination) || window.location.assign(destination)
  })
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

setupNavDropdowns()
setupTreeNavigation()

document.addEventListener("turbo:load", setupSidebars)
document.addEventListener("turbo:render", setupSidebars)
