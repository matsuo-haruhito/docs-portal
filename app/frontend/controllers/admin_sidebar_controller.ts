import { Controller } from "@hotwired/stimulus"

export default class AdminSidebarController extends Controller {
  static targets = ["sidebar"]

  declare sidebarTarget: HTMLElement
  declare hasSidebarTarget: boolean

  toggle(): void {
    if (!this.hasSidebarTarget) return
    this.sidebarTarget.classList.toggle("is-open")
  }
}
