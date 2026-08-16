import { Controller } from "@hotwired/stimulus"

export default class ToastController extends Controller {
  connect(): void {
    setTimeout(() => {
      this.element.classList.remove("show")
      setTimeout(() => this.element.remove(), 300)
    }, 5000)
  }

  dismiss(): void {
    this.element.classList.remove("show")
    setTimeout(() => this.element.remove(), 300)
  }
}
