import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "status"]

  copy(event) {
    event.preventDefault()

    const text = this.templateText
    if (!text) {
      this.showStatus("コピーする依頼テンプレートが見つかりません。")
      return
    }

    if (!navigator.clipboard?.writeText) {
      this.showStatus("コピー機能を使えません。テンプレートを選択してコピーしてください。")
      return
    }

    navigator.clipboard.writeText(text)
      .then(() => this.showStatus("依頼テンプレートをコピーしました。"))
      .catch(() => this.showStatus("コピーできませんでした。テンプレートを選択してコピーしてください。"))
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }

  get templateText() {
    if (!this.hasTemplateTarget) return ""

    return this.templateTarget.textContent.trim()
  }
}
