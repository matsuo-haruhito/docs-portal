import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "status", "category", "targetUser", "requestDetail", "checklist", "userType", "timeline"]
  static values = { companyName: String, requester: String }

  declare readonly hasTemplateTarget: boolean
  declare readonly templateTarget: HTMLTextAreaElement
  declare readonly hasStatusTarget: boolean
  declare readonly statusTarget: HTMLElement
  declare readonly categoryTargets: HTMLInputElement[]
  declare readonly hasRequestDetailTarget: boolean
  declare readonly requestDetailTarget: HTMLInputElement
  declare readonly hasChecklistTarget: boolean
  declare readonly checklistTarget: HTMLInputElement
  declare readonly hasUserTypeTarget: boolean
  declare readonly userTypeTarget: HTMLInputElement
  declare readonly companyNameValue: string
  declare readonly requesterValue: string

  connect(): void {
    this.updateTemplate()
  }

  copy(event: Event): void {
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

  selectCategory(event: Event): void {
    const category = event.currentTarget as HTMLElement
    this.applyCategoryHints(category)
    this.updateTemplate()
  }

  updateTemplate(): void {
    if (!this.hasTemplateTarget) return
    this.templateTarget.value = this.templateLines.join("\n")
  }

  private applyCategoryHints(category: HTMLElement): void {
    if (this.hasRequestDetailTarget) this.requestDetailTarget.value = category.dataset.requestHint || ""
    if (this.hasChecklistTarget) this.checklistTarget.value = category.dataset.checklistHint || ""
    if (this.hasUserTypeTarget) this.userTypeTarget.value = category.dataset.userTypeHint || "なし"
  }

  private showStatus(message: string): void {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }

  private get templateLines(): string[] {
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

  private get selectedCategoryLabel(): string {
    const selected = this.categoryTargets.find((category) => category.checked)
    return (selected as HTMLElement)?.dataset.categoryLabel || "案件・案件所属"
  }

  private get templateText(): string {
    if (!this.hasTemplateTarget) return ""
    return this.templateTarget.value.trim()
  }

  private fieldValue(targetName: string, fallback: string): string {
    const target = (this as unknown as Record<string, HTMLInputElement | undefined>)[`${targetName}Target`]
    return target?.value?.trim() || fallback
  }
}
