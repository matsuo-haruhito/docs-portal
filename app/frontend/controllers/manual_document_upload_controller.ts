import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    sourcePath: String
  }
  static classes = ["dragging"]
  static targets = ["frame", "overlay", "multiFilePreview", "multiFileSummary", "multiFileNames", "multiFileOverflow"]

  declare urlValue: string
  declare sourcePathValue: string
  declare readonly hasFrameTarget: boolean
  declare readonly frameTarget: HTMLIFrameElement
  declare readonly hasOverlayTarget: boolean
  declare readonly overlayTarget: HTMLElement
  declare readonly hasMultiFilePreviewTarget: boolean
  declare readonly multiFilePreviewTarget: HTMLElement
  declare readonly hasMultiFileSummaryTarget: boolean
  declare readonly multiFileSummaryTarget: HTMLElement
  declare readonly hasMultiFileNamesTarget: boolean
  declare readonly multiFileNamesTarget: HTMLElement
  declare readonly hasMultiFileOverflowTarget: boolean
  declare readonly multiFileOverflowTarget: HTMLElement
  declare readonly hasDraggingClass: boolean
  declare readonly draggingClass: string

  private boundWindowDragEnter!: (event: DragEvent) => void
  private boundWindowDragOver!: (event: DragEvent) => void
  private boundWindowDragEnd!: () => void
  private boundHandleFrameLoad!: () => void
  private frameDocumentRef: Document | null = null
  private boundFrameDragEnter!: (event: DragEvent) => void
  private boundFrameDragOver!: (event: DragEvent) => void
  private boundFrameDrop!: (event: DragEvent) => void

  connect(): void {
    this.boundWindowDragEnter = this.windowDragEnter.bind(this)
    this.boundWindowDragOver = this.windowDragOver.bind(this)
    this.boundWindowDragEnd = this.windowDragEnd.bind(this)
    this.boundHandleFrameLoad = this.handleFrameLoad.bind(this)
    window.addEventListener("dragenter", this.boundWindowDragEnter as EventListener)
    window.addEventListener("dragover", this.boundWindowDragOver as EventListener)
    window.addEventListener("drop", this.boundWindowDragEnd as EventListener)
    window.addEventListener("dragend", this.boundWindowDragEnd as EventListener)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundHandleFrameLoad)
      this.handleFrameLoad()
    }
  }

  disconnect(): void {
    window.removeEventListener("dragenter", this.boundWindowDragEnter as EventListener)
    window.removeEventListener("dragover", this.boundWindowDragOver as EventListener)
    window.removeEventListener("drop", this.boundWindowDragEnd as EventListener)
    window.removeEventListener("dragend", this.boundWindowDragEnd as EventListener)

    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundHandleFrameLoad)
    }

    this.disconnectFrameDocument()
  }

  dragenter(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.mark(event.currentTarget as HTMLElement, true)
  }

  dragover(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.mark(event.currentTarget as HTMLElement, true)
  }

  dragleave(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    if ((event.currentTarget as HTMLElement).contains(event.relatedTarget as Node)) return
    this.mark(event.currentTarget as HTMLElement, false)
  }

  drop(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.clearDragState()

    const file = this.singleFileFrom(event)
    if (!file) return

    this.upload(file, event.currentTarget as HTMLElement)
  }

  private handleFrameLoad(): void {
    this.disconnectFrameDocument()

    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.frameDocumentRef = frameDocument
    this.boundFrameDragEnter = this.frameDragEnter.bind(this)
    this.boundFrameDragOver = this.frameDragOver.bind(this)
    this.boundFrameDrop = this.frameDrop.bind(this)

    frameDocument.addEventListener("dragenter", this.boundFrameDragEnter as EventListener)
    frameDocument.addEventListener("dragover", this.boundFrameDragOver as EventListener)
    frameDocument.addEventListener("drop", this.boundFrameDrop as EventListener)
  }

  private disconnectFrameDocument(): void {
    if (!this.frameDocumentRef) return

    this.frameDocumentRef.removeEventListener("dragenter", this.boundFrameDragEnter as EventListener)
    this.frameDocumentRef.removeEventListener("dragover", this.boundFrameDragOver as EventListener)
    this.frameDocumentRef.removeEventListener("drop", this.boundFrameDrop as EventListener)
    this.frameDocumentRef = null
  }

  private frameDocument(): Document | null {
    if (!this.hasFrameTarget) return null
    try {
      return this.frameTarget.contentDocument
    } catch (_error) {
      return null
    }
  }

  private frameDragEnter(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.markFrameDropActive()
  }

  private frameDragOver(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.markFrameDropActive()
  }

  private frameDrop(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.clearDragState()

    const file = this.singleFileFrom(event)
    if (!file) return

    this.upload(file, this.element as HTMLElement)
  }

  private singleFileFrom(event: DragEvent): File | null {
    const files = Array.from(event.dataTransfer?.files || [])
    if (files.length === 0) return null
    if (files.length > 1) {
      this.showMultiFilePreview(files)
      return null
    }

    this.clearMultiFilePreview()
    return files[0]
  }

  private showMultiFilePreview(files: File[]): void {
    if (!this.hasMultiFilePreviewTarget) return

    const visibleFiles = files.slice(0, this.multiFilePreviewLimit)
    const overflowCount = files.length - visibleFiles.length

    this.multiFilePreviewTarget.hidden = false

    if (this.hasMultiFileSummaryTarget) {
      this.multiFileSummaryTarget.textContent = `${files.length}件のファイルが選択されています。1ファイルずつアップロードしてください。`
    }

    if (this.hasMultiFileNamesTarget) {
      this.multiFileNamesTarget.replaceChildren()
      visibleFiles.forEach((file) => {
        const item = document.createElement("li")
        item.textContent = file.name || "名称未設定"
        this.multiFileNamesTarget.appendChild(item)
      })
    }

    if (this.hasMultiFileOverflowTarget) {
      this.multiFileOverflowTarget.hidden = overflowCount <= 0
      this.multiFileOverflowTarget.textContent = overflowCount > 0 ? `ほか${overflowCount}件は表示していません。` : ""
    }
  }

  private clearMultiFilePreview(): void {
    if (this.hasMultiFilePreviewTarget) this.multiFilePreviewTarget.hidden = true
    if (this.hasMultiFileSummaryTarget) this.multiFileSummaryTarget.textContent = ""
    if (this.hasMultiFileNamesTarget) this.multiFileNamesTarget.replaceChildren()
    if (this.hasMultiFileOverflowTarget) {
      this.multiFileOverflowTarget.hidden = true
      this.multiFileOverflowTarget.textContent = ""
    }
  }

  private upload(file: File, target: HTMLElement): void {
    const url = target.dataset.manualDocumentUploadUrl || this.urlValue
    if (!url) return

    this.element.classList.add("is-uploading")
    target.classList.add("is-uploading")

    const form = document.createElement("form")
    form.method = "post"
    form.enctype = "multipart/form-data"
    form.action = url
    form.style.display = "none"

    this.appendHidden(form, "authenticity_token", this.csrfToken())
    this.appendHidden(form, "source_path", target.dataset.manualDocumentUploadSourcePath || this.sourcePathValue || "")
    this.appendHidden(form, "target_document_id", target.dataset.manualDocumentUploadTargetDocumentId || "")

    const input = document.createElement("input")
    input.type = "file"
    input.name = "file"

    const transfer = new DataTransfer()
    transfer.items.add(file)
    input.files = transfer.files

    form.appendChild(input)
    document.body.appendChild(form)
    form.submit()
  }

  private appendHidden(form: HTMLFormElement, name: string, value: string): void {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }

  private csrfToken(): string {
    return document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content || ""
  }

  private mark(target: HTMLElement, active: boolean): void {
    target.classList.toggle(this.draggingClassName, active)
  }

  private markFrameDropActive(): void {
    this.element.classList.add("is-file-dragging")
    this.element.classList.add(this.draggingClassName)

    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add(this.draggingClassName)
    }
  }

  private clearDragState(): void {
    this.element.classList.remove("is-file-dragging")
    this.element.classList.remove(this.draggingClassName)
    document.querySelectorAll(".document-preview-drop-overlay, .manual-document-upload-target, .manual-document-upload-panel, .manual-document-upload-panel__drop").forEach((target) => {
      target.classList.remove("is-file-dragging")
      target.classList.remove(this.draggingClassName)
    })
  }

  private windowDragEnter(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    this.element.classList.add("is-file-dragging")
  }

  private windowDragOver(event: DragEvent): void {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.element.classList.add("is-file-dragging")
  }

  private windowDragEnd(): void {
    this.clearDragState()
  }

  private hasFileDrag(event: DragEvent): boolean {
    return Array.from(event.dataTransfer?.types || []).includes("Files")
  }

  private get multiFilePreviewLimit(): number {
    return 3
  }

  private get draggingClassName(): string {
    return this.hasDraggingClass ? this.draggingClass : "is-dragging"
  }
}
