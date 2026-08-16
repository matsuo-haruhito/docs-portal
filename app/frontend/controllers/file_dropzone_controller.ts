import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "filename"]
  static classes = ["dragging"]

  declare readonly inputTarget: HTMLInputElement
  declare readonly hasFilenameTarget: boolean
  declare readonly filenameTarget: HTMLElement
  declare readonly draggingClass: string

  dragenter(event: DragEvent): void {
    event.preventDefault()
    this.showDragging()
  }

  dragover(event: DragEvent): void {
    event.preventDefault()
    this.showDragging()
  }

  dragleave(event: DragEvent): void {
    event.preventDefault()
    this.hideDragging()
  }

  drop(event: DragEvent): void {
    event.preventDefault()
    this.hideDragging()

    const droppedFiles = event.dataTransfer?.files
    if (!droppedFiles || droppedFiles.length === 0) return

    this.inputTarget.files = droppedFiles
    this.updateFilename()
  }

  change(): void {
    this.updateFilename()
  }

  private showDragging(): void {
    this.element.classList.add(this.draggingClass)
  }

  private hideDragging(): void {
    this.element.classList.remove(this.draggingClass)
  }

  private updateFilename(): void {
    if (!this.hasFilenameTarget) return

    const file = this.inputTarget.files?.[0]
    this.filenameTarget.textContent = file ? file.name : "選択されていません"
  }
}
