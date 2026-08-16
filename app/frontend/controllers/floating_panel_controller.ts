import { Controller } from "@hotwired/stimulus"

/**
 * フローティングパネル: ボタンクリックでパネルを fixed 表示する。
 * overflow や z-index に影響されず、常にトップレイヤーに表示される。
 *
 * HTML構成:
 *   div[data-controller="floating-panel"]
 *     button[data-floating-panel-target="trigger"][data-action="click->floating-panel#toggle"]
 *     div[data-floating-panel-target="panel"].floating-panel
 *       (フォームフィールド等)
 */
export default class FloatingPanelController extends Controller {
  static targets = ["trigger", "panel"]

  declare readonly triggerTarget: HTMLElement
  declare readonly panelTarget: HTMLElement

  private outsideClick!: (event: MouseEvent) => void
  private onScroll!: () => void
  private onKeydown!: (event: KeyboardEvent) => void

  connect(): void {
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.panelTarget.setAttribute("aria-hidden", "true")
    // Turbo再接続時: 前回のis-openとinline styleをクリア
    this.panelTarget.classList.remove("is-open")
    this.panelTarget.style.top = ""
    this.panelTarget.style.left = ""
    this.outsideClick = (event: MouseEvent) => {
      if (!this.element.contains(event.target as Node)) {
        this.close()
      }
    }
    this.onScroll = () => { if (this.isOpen()) this.position() }
    this.onKeydown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && this.isOpen()) {
        event.stopPropagation()
        this.close()
      }
    }
  }

  disconnect(): void {
    this.removeListeners()
  }

  toggle(): void {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open(): void {
    this.panelTarget.classList.add("is-open")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.panelTarget.setAttribute("aria-hidden", "false")
    this.position()
    this.addListeners()
    // フォーカスをパネル内の最初の入力フィールドへ移す
    const firstInput = this.panelTarget.querySelector<HTMLElement>("input, select, textarea")
    if (firstInput) setTimeout(() => firstInput.focus(), 0)
  }

  close(): void {
    const wasOpen = this.isOpen()
    this.panelTarget.classList.remove("is-open")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.panelTarget.setAttribute("aria-hidden", "true")
    this.removeListeners()
    if (wasOpen) this.triggerTarget.focus()
  }

  private isOpen(): boolean {
    return this.panelTarget.classList.contains("is-open")
  }

  private position(): void {
    const rect = this.triggerTarget.getBoundingClientRect()
    const panel = this.panelTarget
    const panelRect = panel.getBoundingClientRect()

    // デフォルトはボタン下方に表示
    let top = rect.bottom + 4
    let left = rect.left

    // 画面右端を超える場合は左寄せ
    if (left + panelRect.width > window.innerWidth - 8) {
      left = window.innerWidth - panelRect.width - 8
    }

    // 画面下端を超える場合は上方に表示
    if (top + panelRect.height > window.innerHeight - 8) {
      top = rect.top - panelRect.height - 4
    }

    panel.style.top = `${Math.max(4, top)}px`
    panel.style.left = `${Math.max(4, left)}px`
  }

  private addListeners(): void {
    document.addEventListener("click", this.outsideClick, true)
    document.addEventListener("scroll", this.onScroll, true)
    document.addEventListener("keydown", this.onKeydown as EventListener, true)
  }

  private removeListeners(): void {
    document.removeEventListener("click", this.outsideClick, true)
    document.removeEventListener("scroll", this.onScroll, true)
    document.removeEventListener("keydown", this.onKeydown as EventListener, true)
  }
}
