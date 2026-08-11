import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "trigger"]

  declare readonly dialogTarget: HTMLDialogElement
  declare readonly triggerTarget: HTMLButtonElement

  open(): void {
    if (this.dialogTarget.open) return

    this.dialogTarget.showModal()
    this.dialogTarget.dispatchEvent(new CustomEvent("column-settings-dialog:opened", { bubbles: true }))
  }

  close(): void {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event: MouseEvent): void {
    if (event.target === this.dialogTarget) this.close()
  }

  restoreFocus(): void {
    this.triggerTarget.focus()
  }
}
