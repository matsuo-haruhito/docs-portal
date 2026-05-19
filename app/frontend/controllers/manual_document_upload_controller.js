import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    sourcePath: String
  }
  static classes = ["dragging"]

  dragenter(event) {
    event.preventDefault()
    this.mark(event.currentTarget, true)
  }

  dragover(event) {
    event.preventDefault()
    this.mark(event.currentTarget, true)
  }

  dragleave(event) {
    event.preventDefault()
    this.mark(event.currentTarget, false)
  }

  drop(event) {
    event.preventDefault()
    this.mark(event.currentTarget, false)

    const files = event.dataTransfer.files
    if (!files || files.length === 0) return

    this.upload(files[0], event.currentTarget)
  }

  upload(file, target) {
    const url = target.dataset.manualDocumentUploadUrl || this.urlValue
    if (!url) return

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

  get draggingClassName() {
    return this.hasDraggingClass ? this.draggingClass : "is-dragging"
  }
}
