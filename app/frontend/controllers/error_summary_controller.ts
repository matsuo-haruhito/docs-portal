import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect(): void {
    window.requestAnimationFrame(() => {
      this.element.scrollIntoView({ behavior: "smooth", block: "center" })
      ;(this.element as HTMLElement).focus({ preventScroll: true })
    })
  }

  focusField(event: Event): void {
    event.preventDefault()
    const link = event.currentTarget as HTMLAnchorElement
    const target = document.querySelector<HTMLElement>(link.hash)
    if (!target) return

    target.scrollIntoView({ behavior: "smooth", block: "center" })
    target.focus({ preventScroll: true })
  }
}
