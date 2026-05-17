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

    this.closeOthers(dropdown)
  }

  onClick(event) {
    const clickedDropdown = event.target.closest("[data-nav-dropdown]")
    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      if (dropdown !== clickedDropdown) dropdown.open = false
    })
  }

  onKeydown(event) {
    if (event.key !== "Escape") return

    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      dropdown.open = false
    })
  }

  closeOthers(currentDropdown) {
    document.querySelectorAll("[data-nav-dropdown][open]").forEach((dropdown) => {
      if (dropdown !== currentDropdown) dropdown.open = false
    })
  }
}
