import { Controller } from "@hotwired/stimulus"

const TAB_DEFINITIONS = [
  { id: "version-diff", label: "差分" },
  { id: "side-by-side-file-review", label: "左右確認" },
  { id: "version-files", label: "添付・元ファイル" },
  { id: "version-info", label: "版情報" }
]

const HASH_TO_TAB = {
  "#version-diff": "version-diff",
  "#markdown-line-diff": "version-diff",
  "#html-rendered-diff": "version-diff",
  "#html-table-cell-diff": "version-diff",
  "#side-by-side-file-review": "side-by-side-file-review",
  "#version-files": "version-files",
  "#version-info": "version-info"
}

function collectUntil(startElement, stopElement) {
  const elements = []
  let current = startElement

  while (current && current !== stopElement) {
    elements.push(current)
    current = current.nextElementSibling
  }

  return elements
}

function wrapPanel(tabId, elements) {
  if (elements.length === 0) {
    return null
  }

  if (elements.length === 1 && elements[0].id === tabId) {
    return elements[0]
  }

  const wrapper = document.createElement("section")
  wrapper.id = tabId
  wrapper.className = "version-detail-tab-panel"

  const firstElement = elements[0]
  firstElement.parentNode.insertBefore(wrapper, firstElement)

  elements.forEach((element) => {
    if (element.id === tabId) {
      element.id = `${tabId}-heading`
    }

    wrapper.appendChild(element)
  })

  return wrapper
}

function existingPanelMap() {
  const diffPanel = document.getElementById("version-diff")
  const sideBySidePanel = document.getElementById("side-by-side-file-review")
  const versionInfoPanel = document.getElementById("version-info")
  const versionFilesPanel = document.getElementById("version-files")

  if (!diffPanel || !sideBySidePanel || !versionInfoPanel || !versionFilesPanel) {
    return null
  }

  return {
    "version-diff": diffPanel,
    "side-by-side-file-review": sideBySidePanel,
    "version-info": versionInfoPanel,
    "version-files": versionFilesPanel
  }
}

function buildPanelMap() {
  const diffPanel = document.getElementById("version-diff")
  const sideBySidePanel = document.getElementById("side-by-side-file-review")
  const filesHeading = document.getElementById("version-files")
  const comments = document.querySelector(".document-comment-workspace")

  if (!diffPanel || !sideBySidePanel || !filesHeading) {
    return null
  }

  return {
    "version-diff": diffPanel,
    "side-by-side-file-review": sideBySidePanel,
    "version-info": wrapPanel("version-info", collectUntil(sideBySidePanel.nextElementSibling, filesHeading)),
    "version-files": wrapPanel("version-files", collectUntil(filesHeading, comments))
  }
}

function normalizeTabId() {
  return HASH_TO_TAB[window.location.hash] || "version-diff"
}

function setPanelAccessibility(panelMap) {
  Object.entries(panelMap).forEach(([tabId, panel]) => {
    if (!panel) {
      return
    }

    panel.setAttribute("role", "tabpanel")
    panel.setAttribute("aria-labelledby", `version-tab-${tabId}`)
  })
}

function renderTabs(nav, panelMap) {
  const originalItems = Array.from(nav.children)
  const secondaryItems = originalItems.filter((item) => {
    if (item.getAttribute("aria-current") === "page" || item.classList.contains("badge")) {
      return false
    }

    if (item.tagName !== "A") {
      return true
    }

    return !(item.getAttribute("href") || "").startsWith("#")
  })

  nav.textContent = ""
  nav.classList.add("version-detail-tabs")
  nav.setAttribute("role", "tablist")

  TAB_DEFINITIONS.forEach(({ id, label }) => {
    if (!panelMap[id]) {
      return
    }

    const tab = document.createElement("a")
    tab.href = `#${id}`
    tab.id = `version-tab-${id}`
    tab.className = "version-detail-tabs__tab"
    tab.setAttribute("role", "tab")
    tab.setAttribute("aria-controls", id)
    tab.dataset.versionTab = id
    tab.textContent = label

    tab.addEventListener("click", (event) => {
      event.preventDefault()
      selectTab(nav, panelMap, tab)
    })

    tab.addEventListener("keydown", (event) => handleTabKeydown(event, nav, panelMap, tab))

    nav.appendChild(tab)
  })

  if (secondaryItems.length > 0) {
    const secondaryGroup = document.createElement("span")
    secondaryGroup.className = "version-detail-tabs__links"

    secondaryItems.forEach((item) => {
      secondaryGroup.appendChild(item)
    })

    nav.appendChild(secondaryGroup)
  }
}

function tabItems(nav) {
  return Array.from(nav.querySelectorAll("[data-version-tab]"))
}

function activateTab(nav, panelMap, activeTabId = normalizeTabId(), options = {}) {
  Object.entries(panelMap).forEach(([tabId, panel]) => {
    if (!panel) {
      return
    }

    panel.hidden = tabId !== activeTabId
  })

  tabItems(nav).forEach((tab) => {
    const active = tab.dataset.versionTab === activeTabId
    tab.setAttribute("aria-selected", String(active))
    tab.tabIndex = active ? 0 : -1

    if (active && options.focus) {
      tab.focus({ preventScroll: true })
    }
  })
}

function selectTab(nav, panelMap, tab, options = {}) {
  if (!tab) {
    return
  }

  if (window.location.hash !== tab.hash) {
    history.pushState(null, "", tab.hash)
  }

  activateTab(nav, panelMap, tab.dataset.versionTab, options)
}

function adjacentTab(nav, currentTab, direction) {
  const tabs = tabItems(nav)
  const currentIndex = tabs.indexOf(currentTab)

  if (currentIndex === -1) {
    return null
  }

  if (direction === "first") {
    return tabs[0]
  }

  if (direction === "last") {
    return tabs[tabs.length - 1]
  }

  const nextIndex = (currentIndex + direction + tabs.length) % tabs.length
  return tabs[nextIndex]
}

function handleTabKeydown(event, nav, panelMap, currentTab) {
  const keyActions = {
    ArrowLeft: -1,
    ArrowUp: -1,
    ArrowRight: 1,
    ArrowDown: 1,
    Home: "first",
    End: "last"
  }

  if (Object.prototype.hasOwnProperty.call(keyActions, event.key)) {
    event.preventDefault()
    selectTab(nav, panelMap, adjacentTab(nav, currentTab, keyActions[event.key]), { focus: true })
    return
  }

  if (event.key === "Enter" || event.key === " ") {
    event.preventDefault()
    selectTab(nav, panelMap, currentTab, { focus: true })
  }
}

export default class DocumentVersionTabsController extends Controller {
  connect() {
    const enhanced = this.element.dataset.versionTabsEnhanced === "true"
    this.panelMap = enhanced ? existingPanelMap() : buildPanelMap()

    if (!this.panelMap) {
      return
    }

    setPanelAccessibility(this.panelMap)

    if (!enhanced) {
      this.element.dataset.versionTabsEnhanced = "true"
      renderTabs(this.element, this.panelMap)
    }

    activateTab(this.element, this.panelMap)
    this.hashChangeHandler = () => activateTab(this.element, this.panelMap)
    window.addEventListener("hashchange", this.hashChangeHandler)
  }

  disconnect() {
    if (!this.hashChangeHandler) {
      return
    }

    window.removeEventListener("hashchange", this.hashChangeHandler)
    this.hashChangeHandler = null
  }
}
