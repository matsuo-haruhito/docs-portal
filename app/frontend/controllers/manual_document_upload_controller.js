import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    sourcePath: String
  }
  static classes = ["dragging"]

  connect() {
    this.boundWindowDragEnter = this.windowDragEnter.bind(this)
    this.boundWindowDragOver = this.windowDragOver.bind(this)
    this.boundWindowDragEnd = this.windowDragEnd.bind(this)
    window.addEventListener("dragenter", this.boundWindowDragEnter)
    window.addEventListener("dragover", this.boundWindowDragOver)
    window.addEventListener("drop", this.boundWindowDragEnd)
    window.addEventListener("dragend", this.boundWindowDragEnd)
  }

  disconnect() {
    window.removeEventListener("dragenter", this.boundWindowDragEnter)
    window.removeEventListener("dragover", this.boundWindowDragOver)
    window.removeEventListener("drop", this.boundWindowDragEnd)
    window.removeEventListener("dragend", this.boundWindowDragEnd)
  }

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
    if (event.currentTarget.contains(event.relatedTarget)) return
    this.mark(event.currentTarget, false)
  }

  drop(event) {
    event.preventDefault()
    this.mark(event.currentTarget, false)
    this.element.classList.remove("is-file-dragging")

    const files = Array.from(event.dataTransfer.files || [])
    if (files.length === 0) return
    if (files.length > 1) {
      window.alert("複数ファイルの同時アップロードはまだ未対応です。ZIPにまとめるか、1ファイルずつアップロードしてください。")
      return
    }

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

  windowDragEnter(event) {
    if (!this.hasFileDrag(event)) return
    this.element.classList.add("is-file-dragging")
  }

  windowDragOver(event) {
    if (!this.hasFileDrag(event)) return
    this.element.classList.add("is-file-dragging")
  }

  windowDragEnd() {
    this.element.classList.remove("is-file-dragging")
    this.element.classList.remove(this.draggingClassName)
  }

  hasFileDrag(event) {
    return Array.from(event.dataTransfer?.types || []).includes("Files")
  }

  get draggingClassName() {
    return this.hasDraggingClass ? this.draggingClass : "is-dragging"
  }
}