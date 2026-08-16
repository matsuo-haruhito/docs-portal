import { Controller } from "@hotwired/stimulus"

const ANCHOR_TARGET_CLASS = "is-text-preview-anchor-target"
const LINE_SELECTOR = "[data-text-preview-line]"
const LINE_HASH_PATTERN = /^#L\d+$/

function targetLineId(): string | null {
  if (!LINE_HASH_PATTERN.test(window.location.hash)) return null
  return decodeURIComponent(window.location.hash.slice(1))
}

export default class extends Controller {
  private boundSyncAnchorTarget!: () => void

  connect(): void {
    this.boundSyncAnchorTarget = this.syncAnchorTarget.bind(this)
    this.syncAnchorTarget()
    window.addEventListener("hashchange", this.boundSyncAnchorTarget)
  }

  disconnect(): void {
    window.removeEventListener("hashchange", this.boundSyncAnchorTarget)
  }

  private syncAnchorTarget(): void {
    const activeLineId = targetLineId()

    this.lineRows().forEach((lineRow) => {
      const active = activeLineId !== null && lineRow.id === activeLineId
      lineRow.classList.toggle(ANCHOR_TARGET_CLASS, active)

      if (active) {
        lineRow.setAttribute("aria-current", "location")
      } else {
        lineRow.removeAttribute("aria-current")
      }
    })
  }

  private lineRows(): HTMLElement[] {
    return Array.from(this.element.querySelectorAll<HTMLElement>(LINE_SELECTOR))
  }
}
