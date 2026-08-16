import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "scopeField"]
  static values = { matchingCount: Number }

  declare readonly checkboxTargets: HTMLInputElement[]
  declare readonly countTargets: HTMLElement[]
  declare readonly scopeFieldTarget: HTMLInputElement
  declare readonly matchingCountValue: number

  private matchingSelection = false

  connect(): void {
    this.matchingSelection = this.scopeFieldTarget.value === "matching"
    this.sync()
  }

  selectPage(): void {
    this.matchingSelection = false
    this.scopeFieldTarget.value = "page"
    this.selectAll(true)
  }

  selectMatching(): void {
    this.matchingSelection = true
    this.scopeFieldTarget.value = "matching"
    this.selectAll(true)
  }

  clearSelection(): void {
    this.matchingSelection = false
    this.scopeFieldTarget.value = "explicit"
    this.selectAll(false)
  }

  sync(event?: Event): void {
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

  private selectAll(checked: boolean): void {
    this.checkboxTargets.forEach((checkbox) => {
      if (checkbox.disabled) return
      checkbox.checked = checked
    })
    this.sync()
  }

  private selectionCountText(count: number): string {
    if (this.matchingSelection) return `${this.matchingCountValue}件選択中（検索結果全体のZIP対象）`
    if (this.scopeFieldTarget.value === "page") return `${count}件選択中（このページ内のZIP対象）`
    return `${count}件選択中（明示選択）`
  }
}
