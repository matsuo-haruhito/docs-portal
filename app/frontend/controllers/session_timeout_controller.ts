import { Controller } from "@hotwired/stimulus"

export default class SessionTimeoutController extends Controller {
  static values = {
    timeoutMinutes: { type: Number, default: 120 },
    warningMinutes: { type: Number, default: 10 }
  }

  declare timeoutMinutesValue: number
  declare warningMinutesValue: number

  private lastActivity = 0
  private warningTimer: ReturnType<typeof setTimeout> | null = null
  private logoutTimer: ReturnType<typeof setTimeout> | null = null
  private trackActivity = (): void => { this.lastActivity = Date.now() }

  connect(): void {
    this.lastActivity = Date.now()
    this.scheduleWarning()

    document.addEventListener("click", this.trackActivity)
    document.addEventListener("keypress", this.trackActivity)
  }

  disconnect(): void {
    if (this.warningTimer) clearTimeout(this.warningTimer)
    if (this.logoutTimer) clearTimeout(this.logoutTimer)
    document.removeEventListener("click", this.trackActivity)
    document.removeEventListener("keypress", this.trackActivity)
  }

  private scheduleWarning(): void {
    const warningTime = (this.timeoutMinutesValue - this.warningMinutesValue) * 60 * 1000
    this.warningTimer = setTimeout(() => {
      this.showWarning()
    }, warningTime)
  }

  private showWarning(): void {
    const elapsed = Date.now() - this.lastActivity
    const timeoutMs = this.timeoutMinutesValue * 60 * 1000
    const warningMs = this.warningMinutesValue * 60 * 1000

    if (elapsed < timeoutMs - warningMs) {
      this.scheduleWarning()
      return
    }

    const banner = document.createElement("div")
    banner.id = "session-timeout-warning"
    banner.className = "alert alert-warning alert-dismissible position-fixed bottom-0 start-50 translate-middle-x mb-3 shadow"
    banner.style.zIndex = "9999"
    banner.style.minWidth = "400px"
    banner.innerHTML = `
      <strong>セッション有効期限</strong>
      <span class="ms-2">あと${this.warningMinutesValue}分でセッションが切れます</span>
      <button type="button" class="btn btn-sm btn-primary ms-3" id="extend-session-btn">延長する</button>
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `
    document.body.appendChild(banner)

    banner.querySelector("#extend-session-btn")!.addEventListener("click", () => {
      this.extendSession()
      banner.remove()
    })

    this.logoutTimer = setTimeout(() => {
      window.location.href = "/auth/sign_in"
    }, this.warningMinutesValue * 60 * 1000)
  }

  private extendSession(): void {
    fetch("/up", { method: "GET", credentials: "same-origin" })
      .then(() => {
        this.lastActivity = Date.now()
        if (this.logoutTimer) clearTimeout(this.logoutTimer)
        this.scheduleWarning()
      })
  }
}
