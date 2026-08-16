import { Controller } from "@hotwired/stimulus"

export default class HelpTooltipController extends Controller {
  private reposition!: () => void

  connect(): void {
    this.reposition = () => this.updatePosition()
    this.element.addEventListener("mouseenter", this.reposition)
    this.element.addEventListener("focusin", this.reposition)
    window.addEventListener("resize", this.reposition)
    window.addEventListener("scroll", this.reposition, true)
  }

  disconnect(): void {
    this.element.removeEventListener("mouseenter", this.reposition)
    this.element.removeEventListener("focusin", this.reposition)
    window.removeEventListener("resize", this.reposition)
    window.removeEventListener("scroll", this.reposition, true)
  }

  updatePosition(): void {
    const rect = this.element.getBoundingClientRect()
    const openLeft = rect.left + (rect.width / 2) > window.innerWidth / 2
    const openAbove = rect.top > window.innerHeight * 0.72
    const openBelow = rect.bottom < window.innerHeight * 0.28

    this.element.classList.toggle("help-tooltip--open-left", openLeft)
    this.element.classList.toggle("help-tooltip--open-right", !openLeft)
    this.element.classList.toggle("help-tooltip--open-above", openAbove)
    this.element.classList.toggle("help-tooltip--open-below", openBelow)
  }
}
