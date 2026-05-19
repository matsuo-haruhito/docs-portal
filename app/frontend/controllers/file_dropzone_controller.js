import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "filename"]
  static classes = ["dragging"]

  dragenter(event) {
    event.preventDefault()
    this.showDragging()
  }

  dragover(event) {
    event.preventDefault()
    this.showDragging()
  }

  dragleave(event) {
    event.preventDefault()
    this.hideDragging()
  }

  drop(event) {
    event.preventDefault()
    this.hideDragging()

    const droppedFiles = event.dataTransfer.files
    if (droppedFiles.length === 0) return

    this.inputTarget.files = droppedFiles
    this.updateFilename()
  }

  change() {
    this.updateFilename()
  }

  showDragging() {
    this.element.classList.add(this.draggingClass)
  }

  hideDragging() {
    this.element.classList.remove(this.draggingClass)
  }

  updateFilename() {
    if (!this.hasFilenameTarget) return

    const file = this.inputTarget.files[0]
    this.filenameTarget.textContent = file ? file.name : "選択されていません"
  }
}
