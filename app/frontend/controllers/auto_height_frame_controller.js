import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    minHeight: Number
  }

  connect() {
    this.boundHandleLoad = this.handleLoad.bind(this)
    this.boundHandleMessage = this.handleMessage.bind(this)
    this.boundResize = this.resize.bind(this)

    window.addEventListener("message", this.boundHandleMessage)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundHandleLoad)
      this.handleLoad()
    }
  }

  disconnect() {
    window.removeEventListener("message", this.boundHandleMessage)

    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundHandleLoad)
    }

    this.disconnectObservers()
  }

  handleLoad() {
    this.disconnectObservers()
    this.observeFrameDocument()
    this.resizeSoon()
  }

  handleMessage(event) {
    if (!this.hasFrameTarget || event.source !== this.frameTarget.contentWindow) return
    if (event.data?.type !== "docs-portal:embedded-viewer-height") return

    const height = Number(event.data.height)
    if (Number.isFinite(height) && height > 0) {
      this.applyHeight(height)
    }
  }

  observeFrameDocument() {
    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    const targets = [frameDocument.documentElement, frameDocument.body].filter(Boolean)

    if (window.ResizeObserver) {
      this.resizeObserver = new ResizeObserver(this.boundResize)
      targets.forEach((target) => this.resizeObserver.observe(target))
    }

    if (window.MutationObserver && frameDocument.body) {
      this.mutationObserver = new MutationObserver(this.boundResize)
      this.mutationObserver.observe(frameDocument.body, { childList: true, subtree: true, attributes: true })
    }

    const fontReady = frameDocument.fonts?.ready
    if (fontReady) {
      fontReady.then(this.boundResize).catch(() => {})
    }
  }

  disconnectObservers() {
    this.resizeObserver?.disconnect()
    this.mutationObserver?.disconnect()
    this.resizeObserver = null
    this.mutationObserver = null
  }

  resizeSoon() {
    window.requestAnimationFrame(() => this.resize())
  }

  resize() {
    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.applyHeight(this.documentHeight(frameDocument))
  }

  documentHeight(frameDocument) {
    const body = frameDocument.body
    const html = frameDocument.documentElement

    return Math.max(
      body?.scrollHeight || 0,
      body?.offsetHeight || 0,
      html?.clientHeight || 0,
      html?.scrollHeight || 0,
      html?.offsetHeight || 0
    )
  }

  applyHeight(height) {
    const minHeight = this.hasMinHeightValue ? this.minHeightValue : 0
    const nextHeight = Math.ceil(Math.max(height, minHeight))
    this.frameTarget.style.height = `${nextHeight}px`
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
