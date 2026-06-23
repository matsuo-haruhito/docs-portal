function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function setShortcutCue(button, label, shortcut) {
  button.setAttribute("aria-label", `${label} (ショートカット: ${shortcut})`)
  button.title = `${label} (${shortcut})`
}

function styleShortcutCue(cue) {
  cue.style.display = "block"
  cue.style.marginTop = ".25rem"
  cue.style.fontSize = ".875rem"
  cue.style.lineHeight = "1.4"
  cue.style.color = "var(--doc-text-muted, #64748b)"
}

function ensureShortcutCue(container, status) {
  let cue = container.querySelector("[data-image-preview-shortcut-cue]")
  if (!cue) {
    cue = document.createElement("span")
    cue.dataset.imagePreviewShortcutCue = "true"
    cue.className = "preview-shortcut-cue"
    status.insertAdjacentElement("afterend", cue)
  }
  styleShortcutCue(cue)
  cue.textContent = "ショートカット: + / - 拡大縮小、0 リセット、F 画面幅、[ / ] 回転。表示はこのブラウザに保存されます。"
  return cue
}

function setupImagePreview(container) {
  if (container.dataset.imagePreviewToolsReady === "true") return null
  container.dataset.imagePreviewToolsReady = "true"

  const image = container.querySelector("[data-image-preview-image]")
  const fitToggle = container.querySelector("[data-image-preview-fit-toggle]")
  const zoomOutButton = container.querySelector("[data-image-preview-zoom-out]")
  const zoomResetButton = container.querySelector("[data-image-preview-zoom-reset]")
  const zoomInButton = container.querySelector("[data-image-preview-zoom-in]")
  const rotateLeftButton = container.querySelector("[data-image-preview-rotate-left]")
  const rotateResetButton = container.querySelector("[data-image-preview-rotate-reset]")
  const rotateRightButton = container.querySelector("[data-image-preview-rotate-right]")
  const status = container.querySelector("[data-image-preview-status]")
  if (!image || !fitToggle || !zoomOutButton || !zoomResetButton || !zoomInButton || !rotateLeftButton || !rotateResetButton || !rotateRightButton || !status) {
    delete container.dataset.imagePreviewToolsReady
    return null
  }

  setShortcutCue(zoomOutButton, "縮小", "- / _")
  setShortcutCue(zoomResetButton, "倍率をリセット", "0")
  setShortcutCue(zoomInButton, "拡大", "+ / =")
  setShortcutCue(rotateLeftButton, "左に90度回転", "[")
  rotateResetButton.setAttribute("aria-label", "回転をリセット")
  rotateResetButton.title = "回転をリセット"
  setShortcutCue(rotateRightButton, "右に90度回転", "]")
  ensureShortcutCue(container, status)

  const storageKey = `docsPortal.imagePreview:${container.dataset.imagePreviewStorageKey || window.location.pathname}`
  const readState = () => {
    try {
      return { fit: true, zoom: 1, rotation: 0, ...JSON.parse(window.localStorage.getItem(storageKey) || "{}") }
    } catch (_error) {
      return { fit: true, zoom: 1, rotation: 0 }
    }
  }
  const writeState = (state) => window.localStorage.setItem(storageKey, JSON.stringify(state))
  const clampZoom = (value) => Math.min(4, Math.max(0.25, value))
  const normalizeRotation = (value) => ((Number(value) % 360) + 360) % 360
  let state = readState()

  const applyState = () => {
    const zoom = clampZoom(Number(state.zoom) || 1)
    const rotation = normalizeRotation(state.rotation || 0)
    state.zoom = zoom
    state.rotation = rotation
    if (state.fit) {
      image.style.maxWidth = "100%"
      image.style.width = "auto"
      image.style.margin = "0 auto"
    } else {
      image.style.maxWidth = "none"
      image.style.width = `${Math.round(zoom * 100)}%`
      image.style.margin = "0"
    }
    image.style.height = "auto"
    image.style.transform = rotation === 0 ? "" : `rotate(${rotation}deg)`
    image.style.transformOrigin = "center center"
    fitToggle.setAttribute("aria-pressed", String(state.fit))
    fitToggle.textContent = state.fit ? "画面に合わせる" : "倍率表示中"
    const fitToggleLabel = state.fit ? "倍率表示に切り替え" : "画面幅に合わせる"
    fitToggle.setAttribute("aria-label", `${fitToggleLabel} (ショートカット: F)`)
    fitToggle.title = `${fitToggleLabel} (F)`
    const scaleLabel = state.fit ? "画面幅" : `${Math.round(zoom * 100)}%`
    const rotationLabel = rotation === 0 ? "回転なし" : `${rotation}°回転`
    status.textContent = `${scaleLabel} / ${rotationLabel}`
    writeState(state)
  }

  const setZoom = (zoom) => {
    state = { ...state, fit: false, zoom: clampZoom(zoom) }
    applyState()
  }

  const setRotation = (rotation) => {
    state = { ...state, rotation: normalizeRotation(rotation) }
    applyState()
  }

  const toggleFit = () => {
    state = { ...state, fit: !state.fit }
    applyState()
  }

  const handleZoomOut = () => setZoom((Number(state.zoom) || 1) - 0.25)
  const handleZoomReset = () => setZoom(1)
  const handleZoomIn = () => setZoom((Number(state.zoom) || 1) + 0.25)
  const handleRotateLeft = () => setRotation((Number(state.rotation) || 0) - 90)
  const handleRotateReset = () => setRotation(0)
  const handleRotateRight = () => setRotation((Number(state.rotation) || 0) + 90)
  const handleKeydown = (event) => {
    if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey || isEditableTarget(event.target)) return

    if (["+", "=", "-", "_", "0", "f", "F", "[", "]"].includes(event.key)) {
      event.preventDefault()
    }

    switch (event.key) {
      case "+":
      case "=":
        setZoom((Number(state.zoom) || 1) + 0.25)
        break
      case "-":
      case "_":
        setZoom((Number(state.zoom) || 1) - 0.25)
        break
      case "0":
        setZoom(1)
        break
      case "f":
      case "F":
        toggleFit()
        break
      case "[":
        setRotation((Number(state.rotation) || 0) - 90)
        break
      case "]":
        setRotation((Number(state.rotation) || 0) + 90)
        break
      default:
        break
    }
  }

  fitToggle.addEventListener("click", toggleFit)
  zoomOutButton.addEventListener("click", handleZoomOut)
  zoomResetButton.addEventListener("click", handleZoomReset)
  zoomInButton.addEventListener("click", handleZoomIn)
  rotateLeftButton.addEventListener("click", handleRotateLeft)
  rotateResetButton.addEventListener("click", handleRotateReset)
  rotateRightButton.addEventListener("click", handleRotateRight)
  document.addEventListener("keydown", handleKeydown)

  applyState()

  return () => {
    fitToggle.removeEventListener("click", toggleFit)
    zoomOutButton.removeEventListener("click", handleZoomOut)
    zoomResetButton.removeEventListener("click", handleZoomReset)
    zoomInButton.removeEventListener("click", handleZoomIn)
    rotateLeftButton.removeEventListener("click", handleRotateLeft)
    rotateResetButton.removeEventListener("click", handleRotateReset)
    rotateRightButton.removeEventListener("click", handleRotateRight)
    document.removeEventListener("keydown", handleKeydown)
    delete container.dataset.imagePreviewToolsReady
  }
}

export function setupImagePreviewTools() {
  return Array.from(document.querySelectorAll("[data-image-preview-tools]"))
    .map(setupImagePreview)
    .filter(Boolean)
}
