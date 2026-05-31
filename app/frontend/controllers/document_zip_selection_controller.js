import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "scopeField"]
  static values = { matchingCount: Number }

  connect() {
    this.matchingSelection = this.scopeFieldTarget.value === "matching"
    this.sync()
  }

  selectPage() {
    this.matchingSelection = false
    this.scopeFieldTarget.value = "page"
    this.selectAll(true)
  }

  selectMatching() {
    this.matchingSelection = true
    this.scopeFieldTarget.value = "matching"
    this.selectAll(true)
  }

  clearSelection() {
    this.matchingSelection = false
    this.scopeFieldTarget.value = "explicit"
    this.selectAll(false)
  }

  sync(event) {
    if (event) {
      this.matchingSelection = false
      this.scopeFieldTarget.value = "explicit"
    }

    const count = this.checkboxTargets.filter((checkbox) => !checkbox.disabled && checkbox.checked).length
    const text = this.selectionCountText(count)
    this.countTargets.forEach((target) => {
      target.textContent = text
    })
  }

  selectAll(checked) {
    this.checkboxTargets.forEach((checkbox) => {
      if (checkbox.disabled) return
      checkbox.checked = checked
    })
    this.sync()
  }

  selectionCountText(count) {
    if (this.matchingSelection) return `${this.matchingCountValue}件選択中（検索結果全体のZIP対象）`
    if (this.scopeFieldTarget.value === "page") return `${count}件選択中（このページ内のZIP対象）`

    return `${count}件選択中（明示選択）`
  }
}
