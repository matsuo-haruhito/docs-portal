function isEditableTarget(target) {
  return ["INPUT", "TEXTAREA", "SELECT"].includes(target?.tagName) || target?.isContentEditable
}

function setupImagePreview(container) {
  if (container.dataset.imagePreviewToolsReady === "true") return
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
  if (!image || !fitToggle || !zoomOutButton || !zoomResetButton || !zoomInButton || !rotateLeftButton || !rotateResetButton || !rotateRightButton || !status) return

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

  fitToggle.addEventListener("click", toggleFit)
  zoomOutButton.addEventListener("click", () => setZoom((Number(state.zoom) || 1) - 0.25))
  zoomResetButton.addEventListener("click", () => setZoom(1))
  zoomInButton.addEventListener("click", () => setZoom((Number(state.zoom) || 1) + 0.25))
  rotateLeftButton.addEventListener("click", () => setRotation((Number(state.rotation) || 0) - 90))
  rotateResetButton.addEventListener("click", () => setRotation(0))
  rotateRightButton.addEventListener("click", () => setRotation((Number(state.rotation) || 0) + 90))

  document.addEventListener("keydown", (event) => {
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
  })

  applyState()
}

export function setupImagePreviewTools() {
  document.querySelectorAll("[data-image-preview-tools]").forEach(setupImagePreview)
}
