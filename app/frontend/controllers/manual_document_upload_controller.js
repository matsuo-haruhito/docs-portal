import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    sourcePath: String
  }
  static classes = ["dragging"]
  static targets = ["frame", "overlay", "multiFilePreview", "multiFileSummary", "multiFileNames", "multiFileOverflow"]

  connect() {
    this.boundWindowDragEnter = this.windowDragEnter.bind(this)
    this.boundWindowDragOver = this.windowDragOver.bind(this)
    this.boundWindowDragEnd = this.windowDragEnd.bind(this)
    this.boundHandleFrameLoad = this.handleFrameLoad.bind(this)
    window.addEventListener("dragenter", this.boundWindowDragEnter)
    window.addEventListener("dragover", this.boundWindowDragOver)
    window.addEventListener("drop", this.boundWindowDragEnd)
    window.addEventListener("dragend", this.boundWindowDragEnd)

    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("load", this.boundHandleFrameLoad)
      this.handleFrameLoad()
    }
  }

  disconnect() {
    window.removeEventListener("dragenter", this.boundWindowDragEnter)
    window.removeEventListener("dragover", this.boundWindowDragOver)
    window.removeEventListener("drop", this.boundWindowDragEnd)
    window.removeEventListener("dragend", this.boundWindowDragEnd)

    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("load", this.boundHandleFrameLoad)
    }

    this.disconnectFrameDocument()
  }

  dragenter(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.mark(event.currentTarget, true)
  }

  dragover(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.mark(event.currentTarget, true)
  }

  dragleave(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    if (event.currentTarget.contains(event.relatedTarget)) return
    this.mark(event.currentTarget, false)
  }

  drop(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.clearDragState()

    const file = this.singleFileFrom(event)
    if (!file) return

    this.upload(file, event.currentTarget)
  }

  handleFrameLoad() {
    this.disconnectFrameDocument()

    const frameDocument = this.frameDocument()
    if (!frameDocument) return

    this.frameDocumentRef = frameDocument
    this.boundFrameDragEnter = this.frameDragEnter.bind(this)
    this.boundFrameDragOver = this.frameDragOver.bind(this)
    this.boundFrameDrop = this.frameDrop.bind(this)

    frameDocument.addEventListener("dragenter", this.boundFrameDragEnter)
    frameDocument.addEventListener("dragover", this.boundFrameDragOver)
    frameDocument.addEventListener("drop", this.boundFrameDrop)
  }

  disconnectFrameDocument() {
    if (!this.frameDocumentRef) return

    this.frameDocumentRef.removeEventListener("dragenter", this.boundFrameDragEnter)
    this.frameDocumentRef.removeEventListener("dragover", this.boundFrameDragOver)
    this.frameDocumentRef.removeEventListener("drop", this.boundFrameDrop)
    this.frameDocumentRef = null
  }

  frameDocument() {
    if (!this.hasFrameTarget) return null

    try {
      return this.frameTarget.contentDocument
    } catch (_error) {
      return null
    }
  }

  frameDragEnter(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.markFrameDropActive()
  }

  frameDragOver(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.markFrameDropActive()
  }

  frameDrop(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.clearDragState()

    const file = this.singleFileFrom(event)
    if (!file) return

    this.upload(file, this.element)
  }

  singleFileFrom(event) {
    const files = Array.from(event.dataTransfer?.files || [])
    if (files.length === 0) return null
    if (files.length > 1) {
      this.showMultiFilePreview(files)
      return null
    }

    this.clearMultiFilePreview()
    return files[0]
  }

  showMultiFilePreview(files) {
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

  clearMultiFilePreview() {
    if (this.hasMultiFilePreviewTarget) {
      this.multiFilePreviewTarget.hidden = true
    }
    if (this.hasMultiFileSummaryTarget) {
      this.multiFileSummaryTarget.textContent = ""
    }
    if (this.hasMultiFileNamesTarget) {
      this.multiFileNamesTarget.replaceChildren()
    }
    if (this.hasMultiFileOverflowTarget) {
      this.multiFileOverflowTarget.hidden = true
      this.multiFileOverflowTarget.textContent = ""
    }
  }

  upload(file, target) {
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

  appendHidden(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  mark(target, active) {
    target.classList.toggle(this.draggingClassName, active)
  }

  markFrameDropActive() {
    this.element.classList.add("is-file-dragging")
    this.element.classList.add(this.draggingClassName)

    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.add(this.draggingClassName)
    }
  }

  clearDragState() {
    this.element.classList.remove("is-file-dragging")
    this.element.classList.remove(this.draggingClassName)
    document.querySelectorAll(".document-preview-drop-overlay, .manual-document-upload-target, .manual-document-upload-panel, .manual-document-upload-panel__drop").forEach((target) => {
      target.classList.remove("is-file-dragging")
      target.classList.remove(this.draggingClassName)
    })
  }

  windowDragEnter(event) {
    if (!this.hasFileDrag(event)) return
    this.element.classList.add("is-file-dragging")
  }

  windowDragOver(event) {
    if (!this.hasFileDrag(event)) return
    event.preventDefault()
    this.element.classList.add("is-file-dragging")
  }

  windowDragEnd() {
    this.clearDragState()
  }

  hasFileDrag(event) {
    return Array.from(event.dataTransfer?.types || []).includes("Files")
  }

  get multiFilePreviewLimit() {
    return 3
  }

  get draggingClassName() {
    return this.hasDraggingClass ? this.draggingClass : "is-dragging"
  }
}
