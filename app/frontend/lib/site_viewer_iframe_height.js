const HEIGHT_MESSAGE_TYPE = "docs-portal:site-viewer-height"
const MIN_FRAME_HEIGHT = 320

function normalizeFrameHeight(value) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue) || numericValue <= 0) return null
  return Math.max(Math.ceil(numericValue), MIN_FRAME_HEIGHT)
}

function currentFrameHeight(frame) {
  try {
    const frameDocument = frame.contentDocument
    const body = frameDocument?.body
    const root = frameDocument?.documentElement
    return normalizeFrameHeight(
      Math.max(
        body?.scrollHeight || 0,
        body?.offsetHeight || 0,
        root?.scrollHeight || 0,
        root?.offsetHeight || 0,
        root?.clientHeight || 0
      )
    )
  } catch (_error) {
    return null
  }
}

function applyFrameHeight(frame, height) {
  const normalizedHeight = normalizeFrameHeight(height)
  if (!normalizedHeight) return

  frame.style.height = `${normalizedHeight}px`
  frame.dataset.docsPortalAutoHeightApplied = "true"
}

function syncFrameHeight(frame) {
  const height = currentFrameHeight(frame)
  if (!height) return
  applyFrameHeight(frame, height)
}

function handleViewerHeightMessage(event) {
  if (event.origin !== window.location.origin) return
  if (event.data?.type !== HEIGHT_MESSAGE_TYPE) return

  document.querySelectorAll("iframe.site-viewer-frame[data-docs-portal-auto-height='true']").forEach((frame) => {
    if (frame.contentWindow !== event.source) return
    applyFrameHeight(frame, event.data.height)
  })
}

let messageListenerReady = false

export function setupSiteViewerIframeHeightSync() {
  if (!messageListenerReady) {
    window.addEventListener("message", handleViewerHeightMessage)
    messageListenerReady = true
  }

  document.querySelectorAll("iframe.site-viewer-frame[data-docs-portal-auto-height='true']").forEach((frame) => {
    if (frame.dataset.docsPortalAutoHeightReady !== "true") {
      frame.dataset.docsPortalAutoHeightReady = "true"
      frame.addEventListener("load", () => {
        window.requestAnimationFrame(() => syncFrameHeight(frame))
      })
    }

    syncFrameHeight(frame)
  })
}
