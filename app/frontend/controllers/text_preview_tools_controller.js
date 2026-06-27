import { Controller } from "@hotwired/stimulus"

const ANCHOR_TARGET_CLASS = "is-text-preview-anchor-target"
const LINE_SELECTOR = "[data-text-preview-line]"
const LINE_HASH_PATTERN = /^#L\d+$/

function targetLineId() {
  if (!LINE_HASH_PATTERN.test(window.location.hash)) {
    return null
  }

  return decodeURIComponent(window.location.hash.slice(1))
}

export default class extends Controller {
  connect() {
    this.syncAnchorTarget = this.syncAnchorTarget.bind(this)
    this.syncAnchorTarget()
    window.addEventListener("hashchange", this.syncAnchorTarget)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.syncAnchorTarget)
  }

  syncAnchorTarget() {
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

  lineRows() {
    return Array.from(this.element.querySelectorAll(LINE_SELECTOR))
  }
}
