import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = {
    minHeight: Number
  }

  declare readonly hasFrameTarget: boolean
  declare readonly frameTarget: HTMLIFrameElement
  declare readonly hasMinHeightValue: boolean
  declare readonly minHeightValue: number

  private boundHandleLoad!: () => void
  private boundHandleMessage!: (event: MessageEvent) => void
  private boundResize!: () => void
  private resizeObserver: ResizeObserver | null = null
  private mutationObserver: MutationObserver | null = null

  connect(): void {
    this.boundHandleLoad = this.handleLoad.bind(this)
    this.boundHandleMessage = this.handleMessage.bind(this)
    this.boundResize = this.resize.bind(this)

    window.addEventListener("message", this.boundHandleMessage)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundHandleLoad)
      this.handleLoad()
    }
  }

  disconnect(): void {
    window.removeEventListener("message", this.boundHandleMessage)

    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundHandleLoad)
    }

    this.disconnectObservers()
  }

  private handleLoad(): void {
    this.disconnectObservers()
    this.observeFrameDocument()
    this.resizeSoon()
  }

  private handleMessage(event: MessageEvent): void {
    if (!this.hasFrameTarget || event.source !== this.frameTarget.contentWindow) return
    if (event.data?.type !== "docs-portal:embedded-viewer-height") return

    const height = Number(event.data.height)
    if (Number.isFinite(height) && height > 0) {
      this.applyHeight(height)
    }
  }

  private observeFrameDocument(): void {
    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    const targets = [frameDocument.documentElement, frameDocument.body].filter(Boolean)

    this.resizeObserver = new ResizeObserver(this.boundResize)
    targets.forEach((target) => this.resizeObserver!.observe(target))

    if (frameDocument.body) {
      this.mutationObserver = new MutationObserver(this.boundResize)
      this.mutationObserver.observe(frameDocument.body, { childList: true, subtree: true, attributes: true })
    }

    const fontReady = frameDocument.fonts?.ready
    if (fontReady) {
      fontReady.then(this.boundResize).catch(() => {})
    }
  }

  private disconnectObservers(): void {
    this.resizeObserver?.disconnect()
    this.mutationObserver?.disconnect()
    this.resizeObserver = null
    this.mutationObserver = null
  }

  private resizeSoon(): void {
    window.requestAnimationFrame(() => this.resize())
  }

  private resize(): void {
    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.applyHeight(this.documentHeight(frameDocument))
  }

  private documentHeight(frameDocument: Document): number {
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

  private applyHeight(height: number): void {
    const minHeight = this.hasMinHeightValue ? this.minHeightValue : 0
    const nextHeight = Math.ceil(Math.max(height, minHeight))
    this.frameTarget.style.height = `${nextHeight}px`
  }

  private frameDocument(): Document | null {
    if (!this.hasFrameTarget) return null

    try {
      return this.frameTarget.contentDocument
    } catch (_error) {
      return null
    }
  }
}
