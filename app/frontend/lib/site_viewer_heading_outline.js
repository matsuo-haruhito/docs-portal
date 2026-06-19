const HEADING_SELECTOR = "h1, h2, h3"
const MAX_VISIBLE_HEADINGS = 24

function readFrameDocument(frame) {
  try {
    return frame.contentDocument || frame.contentWindow?.document || null
  } catch (_error) {
    return null
  }
}

function headingText(heading) {
  return heading.textContent?.replace(/\s+/g, " ").trim() || ""
}

function headingLevel(heading) {
  const level = Number(heading.tagName.replace("H", ""))
  return Number.isFinite(level) ? level : 2
}

function outlineFrameFor(container) {
  return container.closest(".site-viewer-shell")?.querySelector("iframe.site-viewer-frame[data-docs-portal-heading-outline='true']") || null
}

function setOutlineState(container, message) {
  const summary = container.querySelector("[data-docs-portal-heading-outline-summary]")
  const list = container.querySelector("[data-docs-portal-heading-outline-list]")

  container.hidden = false
  if (summary) summary.textContent = message
  if (list) list.replaceChildren()
}

function activateHeadingButton(button) {
  const list = button.closest("[data-docs-portal-heading-outline-list]")
  list?.querySelectorAll(".site-viewer-outline__item.is-active, .site-viewer-outline__item[aria-current='location']").forEach((item) => {
    item.classList.remove("is-active")
    item.removeAttribute("aria-current")
  })

  button.classList.add("is-active")
  button.setAttribute("aria-current", "location")
}

function buildHeadingButton(frame, heading) {
  const button = document.createElement("button")
  button.type = "button"
  button.className = `site-viewer-outline__item is-level-${headingLevel(heading)}`
  button.textContent = headingText(heading)

  button.addEventListener("click", () => {
    activateHeadingButton(button)

    try {
      heading.scrollIntoView({ behavior: "smooth", block: "start" })
      frame.contentWindow?.focus()
    } catch (_error) {
      heading.scrollIntoView()
    }
  })

  return button
}

function renderHeadingOutline(container) {
  const frame = outlineFrameFor(container)
  if (!frame) {
    container.hidden = true
    return
  }

  const frameDocument = readFrameDocument(frame)
  if (!frameDocument?.body) {
    setOutlineState(container, "見出しを取得できませんでした。本文側の通常スクロールで確認してください。")
    return
  }

  const summary = container.querySelector("[data-docs-portal-heading-outline-summary]")
  const list = container.querySelector("[data-docs-portal-heading-outline-list]")
  const headings = Array.from(frameDocument.querySelectorAll(HEADING_SELECTOR)).filter((heading) => headingText(heading))

  container.hidden = false
  if (!list || headings.length === 0) {
    setOutlineState(container, "見出しはありません。本文側の通常スクロールで確認してください。")
    return
  }

  list.replaceChildren()
  headings.slice(0, MAX_VISIBLE_HEADINGS).forEach((heading) => {
    list.appendChild(buildHeadingButton(frame, heading))
  })

  const omittedCount = Math.max(headings.length - MAX_VISIBLE_HEADINGS, 0)
  if (summary) {
    summary.textContent = omittedCount > 0 ? `${headings.length}件の見出し（先頭${MAX_VISIBLE_HEADINGS}件を表示・後続は本文スクロールで確認）` : `${headings.length}件の見出し（クリックで本文位置へ移動）`
  }
}

export function setupSiteViewerHeadingOutline() {
  document.querySelectorAll("[data-docs-portal-heading-outline='true'].site-viewer-outline").forEach((container) => {
    const frame = outlineFrameFor(container)
    if (frame && frame.dataset.docsPortalHeadingOutlineReady !== "true") {
      frame.dataset.docsPortalHeadingOutlineReady = "true"
      frame.addEventListener("load", () => {
        window.requestAnimationFrame(() => renderHeadingOutline(container))
      })
    }

    renderHeadingOutline(container)
  })
}
