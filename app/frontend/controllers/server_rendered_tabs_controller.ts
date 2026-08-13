import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]

  declare readonly tabTargets: HTMLAnchorElement[]

  connect(): void {
    this.tabTargets.forEach((tab) => {
      tab.tabIndex = tab.getAttribute("aria-selected") === "true" ? 0 : -1
    })
  }

  keydown(event: KeyboardEvent): void {
    const currentTab = event.currentTarget as HTMLAnchorElement
    const currentIndex = this.tabTargets.indexOf(currentTab)
    if (currentIndex < 0) return

    if (event.key === " ") {
      event.preventDefault()
      currentTab.click()
      return
    }

    let nextIndex: number | null = null

    switch (event.key) {
      case "ArrowRight":
        nextIndex = (currentIndex + 1) % this.tabTargets.length
        break
      case "ArrowLeft":
        nextIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
        break
      case "Home":
        nextIndex = 0
        break
      case "End":
        nextIndex = this.tabTargets.length - 1
        break
      default:
        return
    }

    event.preventDefault()
    this.focusTab(nextIndex)
  }

  private focusTab(index: number): void {
    this.tabTargets.forEach((tab, tabIndex) => {
      tab.tabIndex = tabIndex === index ? 0 : -1
    })
    this.tabTargets[index].focus()
  }
}
