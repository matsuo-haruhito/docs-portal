import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onToggle = this.onToggle.bind(this)
    this.onClick = this.onClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)

    document.addEventListener("toggle", this.onToggle, true)
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("toggle", this.onToggle, true)
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKeydown)
  }

  onToggle(event) {
    const dropdown = event.target.closest?.("[data-nav-dropdown]")
    if (!dropdown || !dropdown.open) return

    this.closeOpenDropdowns(dropdown)
  }

  onClick(event) {
    const clickedDropdown = event.target.closest?.("[data-nav-dropdown]")
    if (clickedDropdown) return

    this.closeOpenDropdowns()
  }

  onKeydown(event) {
    if (event.key !== "Escape") return

    const dropdownToRestoreFocus = event.target.closest?.("[data-nav-dropdown][open]") || this.openDropdowns[0]
    this.closeOpenDropdowns()
    this.restoreDropdownSummaryFocus(dropdownToRestoreFocus)
  }

  closeOpenDropdowns(exceptDropdown = null) {
    this.openDropdowns.forEach((dropdown) => {
      if (dropdown !== exceptDropdown) dropdown.open = false
    })
  }

  restoreDropdownSummaryFocus(dropdown) {
    const summary = dropdown?.querySelector?.("summary.nav-dropdown__summary")
    summary?.focus?.()
  }

  get openDropdowns() {
    return this.element.querySelectorAll("[data-nav-dropdown][open]")
  }
}
