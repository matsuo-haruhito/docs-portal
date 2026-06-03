import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  selectedLoadError(event) {
    this.show(event, "選択済みの文書名を読み込めませんでした。文書名を再選択してください。")
  }

  clear(event) {
    const surface = event.detail?.surface || this.findSurface(event.currentTarget)
    if (!surface) return

    surface.textContent = ""
    surface.hidden = true
  }

  show(event, message) {
    const surface = event.detail?.surface || this.findSurface(event.currentTarget)
    if (!surface) return

    const status = event.detail?.status
    surface.textContent = status ? `${message}（HTTP ${status}）` : message
    surface.hidden = false
  }

  findSurface(target) {
    const surfaceId = target?.dataset?.railsFieldsKitTomSelectErrorSurfaceIdValue
    if (!surfaceId) return null

    return document.getElementById(surfaceId)
  }
}
