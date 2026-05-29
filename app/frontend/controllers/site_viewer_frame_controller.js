import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    minHeight: { type: Number, default: 520 },
    maxHeight: { type: Number, default: 20000 }
  }

  connect() {
    this.boundResize = this.resizeToContent.bind(this)
    this.boundScheduleResize = this.scheduleResize.bind(this)
    this.boundMessage = this.handleMessage.bind(this)
    window.addEventListener("resize", this.boundScheduleResize)
    window.addEventListener("message", this.boundMessage)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundResize)
      this.resizeToContent()
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.boundScheduleResize)
    window.removeEventListener("message", this.boundMessage)

    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundResize)
    }

    this.disconnectObservers()
    this.cancelScheduledResize()
  }

  resizeToContent() {
    this.disconnectObservers()

    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.frameDocumentRef = frameDocument
    this.observeFrameDocument(frameDocument)
    this.applyHeight(this.measuredHeight(frameDocument))
  }

  scheduleResize() {
    this.cancelScheduledResize()
    this.resizeRequest = window.requestAnimationFrame(() => {
      this.resizeRequest = null
      this.resizeToContent()
    })
  }

  cancelScheduledResize() {
    if (!this.resizeRequest) return

    window.cancelAnimationFrame(this.resizeRequest)
    this.resizeRequest = null
  }

  observeFrameDocument(frameDocument) {
    const observedTargets = [frameDocument.documentElement, frameDocument.body].filter(Boolean)

    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(this.boundScheduleResize)
      observedTargets.forEach((target) => this.resizeObserver.observe(target))
    }

    this.mutationObserver = new MutationObserver(this.boundScheduleResize)
    observedTargets.forEach((target) => {
      this.mutationObserver.observe(target, {
        attributes: true,
        childList: true,
        subtree: true,
        characterData: true
      })
    })
  }

  disconnectObservers() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }

    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
      this.mutationObserver = null
    }

    this.frameDocumentRef = null
  }

  handleMessage(event) {
    if (!this.hasFrameTarget || event.source !== this.frameTarget.contentWindow) return
    if (!event.data || event.data.type !== "docs-portal:site-viewer-height") return

    this.applyHeight(event.data.height)
  }

  applyHeight(value) {
    const height = Number(value)
    if (!Number.isFinite(height) || height <= 0) return

    const nextHeight = Math.min(this.maxHeightValue, Math.max(this.minHeightValue, Math.ceil(height)))
    this.frameTarget.style.height = `${nextHeight}px`
  }

  measuredHeight(frameDocument) {
    const body = frameDocument.body
    const documentElement = frameDocument.documentElement
    const candidates = [body, documentElement].filter(Boolean).flatMap((element) => [
      element.scrollHeight,
      element.offsetHeight,
      element.clientHeight
    ])

    return Math.max(0, ...candidates)
  }

  frameDocument() {
    if (!this.hasFrameTarget) return null

    try {
      return this.frameTarget.contentDocument
    } catch (_error) {
      return null
    }
  }
}
