import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "status", "category", "targetUser", "requestDetail", "checklist", "userType", "timeline"]
  static values = { companyName: String, requester: String }

  connect() {
    this.updateTemplate()
  }

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

  selectCategory(event) {
    const category = event.currentTarget
    this.applyCategoryHints(category)
    this.updateTemplate()
  }

  updateTemplate() {
    if (!this.hasTemplateTarget) return

    this.templateTarget.value = this.templateLines.join("\n")
  }

  applyCategoryHints(category) {
    if (this.hasRequestDetailTarget) this.requestDetailTarget.value = category.dataset.requestHint || ""
    if (this.hasChecklistTarget) this.checklistTarget.value = category.dataset.checklistHint || ""
    if (this.hasUserTypeTarget) this.userTypeTarget.value = category.dataset.userTypeHint || "なし"
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }

  get templateLines() {
    return [
      `【会社】${this.companyNameValue || "自社会社名"}`,
      `【依頼者】${this.requesterValue || "依頼者名・連絡先"}`,
      `【分類】${this.selectedCategoryLabel}`,
      `【対象ユーザー】${this.fieldValue("targetUser", "名前 / メールアドレス")}`,
      `【依頼内容】${this.fieldValue("requestDetail", "必要な案件所属、文書権限、アクセス申請など")}`,
      `【確認項目】${this.fieldValue("checklist", "internal admin に確認してほしい項目")}`,
      `【user type 変更相談】${this.fieldValue("userType", "あり / なし")}`,
      `【期限・背景】${this.fieldValue("timeline", "理由と希望時期")}`
    ]
  }

  get selectedCategoryLabel() {
    const selected = this.categoryTargets.find((category) => category.checked)
    return selected?.dataset.categoryLabel || "案件・案件所属"
  }

  get templateText() {
    if (!this.hasTemplateTarget) return ""

    return this.templateTarget.value.trim()
  }

  fieldValue(targetName, fallback) {
    const target = this[`${targetName}Target`]
    return target?.value?.trim() || fallback
  }
}
