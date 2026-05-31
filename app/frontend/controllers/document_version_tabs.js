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

function buildPanelMap() {
  const diffPanel = document.getElementById("version-diff")
  const sideBySidePanel = document.getElementById("side-by-side-file-review")
  const filesHeading = document.getElementById("version-files")
  const comments = document.querySelector(".document-comment-workspace")

  if (!diffPanel || !sideBySidePanel || !filesHeading) {
    return null
  }

  return {
    "version-diff": [diffPanel],
    "side-by-side-file-review": [sideBySidePanel],
    "version-info": collectUntil(sideBySidePanel.nextElementSibling, filesHeading),
    "version-files": collectUntil(filesHeading, comments)
  }
}

function normalizeTabId() {
  return HASH_TO_TAB[window.location.hash] || "version-diff"
}

function setPanelAccessibility(panelMap) {
  Object.entries(panelMap).forEach(([tabId, elements]) => {
    const firstElement = elements[0]

    if (!firstElement) {
      return
    }

    firstElement.setAttribute("role", "tabpanel")
    firstElement.setAttribute("aria-labelledby", `version-tab-${tabId}`)

    if (tabId === "version-info" && !firstElement.id) {
      firstElement.id = tabId
    }
  })
}

function renderTabs(nav, panelMap) {
  const originalItems = Array.from(nav.children)
  const secondaryItems = originalItems.filter((item) => {
    if (item.tagName !== "A") {
      return true
    }

    return !(item.getAttribute("href") || "").startsWith("#")
  })

  nav.textContent = ""
  nav.classList.add("version-detail-tabs")
  nav.setAttribute("role", "tablist")

  TAB_DEFINITIONS.forEach(({ id, label }) => {
    if (!panelMap[id]?.length) {
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
      history.pushState(null, "", tab.hash)
      activateTab(nav, panelMap, id)
    })

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

function activateTab(nav, panelMap, activeTabId = normalizeTabId()) {
  Object.entries(panelMap).forEach(([tabId, elements]) => {
    const active = tabId === activeTabId

    elements.forEach((element) => {
      element.hidden = !active
    })
  })

  nav.querySelectorAll("[data-version-tab]").forEach((tab) => {
    const active = tab.dataset.versionTab === activeTabId
    tab.setAttribute("aria-selected", String(active))
    tab.tabIndex = active ? 0 : -1
  })
}

function enhanceVersionTabs(nav) {
  if (nav.dataset.versionTabsEnhanced === "true") {
    return
  }

  const panelMap = buildPanelMap()

  if (!panelMap) {
    return
  }

  nav.dataset.versionTabsEnhanced = "true"
  setPanelAccessibility(panelMap)
  renderTabs(nav, panelMap)
  activateTab(nav, panelMap)

  window.addEventListener("hashchange", () => activateTab(nav, panelMap))
}

function setupDocumentVersionTabs() {
  document.querySelectorAll('nav.markdown-mode-tabs[aria-label="版詳細ナビゲーション"]').forEach(enhanceVersionTabs)
}

document.addEventListener("turbo:load", setupDocumentVersionTabs)
document.addEventListener("DOMContentLoaded", setupDocumentVersionTabs)
