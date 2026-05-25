import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count"]

  connect() {
    this.sync()
  }

  selectPage() {
    this.selectAll(true)
  }

  clearSelection() {
    this.selectAll(false)
  }

  sync() {
    const count = this.checkboxTargets.filter((checkbox) => !checkbox.disabled && checkbox.checked).length
    this.countTargets.forEach((target) => {
      target.textContent = `${count}件選択中`
    })
  }

  selectAll(checked) {
    this.checkboxTargets.forEach((checkbox) => {
      if (checkbox.disabled) return
      checkbox.checked = checked
    })
    this.sync()
  }
}
