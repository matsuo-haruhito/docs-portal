import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]

  declare tabTargets: HTMLAnchorElement[]
  private observer: IntersectionObserver | null = null

  connect(): void {
    this.setupObserver()
  }

  disconnect(): void {
    this.observer?.disconnect()
    this.observer = null
  }

  scrollToSection(event: MouseEvent): void {
    event.preventDefault()

    const tab = event.currentTarget as HTMLAnchorElement
    const sectionId = tab.getAttribute("aria-controls")
    if (!sectionId) return

    const section = document.getElementById(sectionId)
    if (!section) return

    this.openContainingDetails(section)
    this.activateTab(sectionId)

    window.requestAnimationFrame(() => {
      const navHeight = this.element.getBoundingClientRect().height
      const top = section.getBoundingClientRect().top + window.scrollY - navHeight
      window.scrollTo({ top, behavior: "smooth" })
    })
  }

  navigateWithKeyboard(event: KeyboardEvent): void {
    const currentTab = event.currentTarget as HTMLAnchorElement
    const currentIndex = this.tabTargets.indexOf(currentTab)
    if (currentIndex < 0) return

    let nextIndex: number | null = null

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        nextIndex = (currentIndex + 1) % this.tabTargets.length
        break
      case "ArrowLeft":
      case "ArrowUp":
        nextIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
        break
      case "Home":
        nextIndex = 0
        break
      case "End":
        nextIndex = this.tabTargets.length - 1
        break
      default:
        return
    }

    event.preventDefault()
    const nextTab = this.tabTargets[nextIndex]
    nextTab.focus()
    nextTab.click()
  }

  private setupObserver(): void {
    if (typeof IntersectionObserver === "undefined") return

    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { rootMargin: "-0% 0% -70% 0%", threshold: 0 }
    )

    this.tabTargets.forEach((tab) => {
      const sectionId = tab.getAttribute("aria-controls")
      const section = sectionId ? document.getElementById(sectionId) : null
      if (section) this.observer!.observe(section)
    })
  }

  private handleIntersection(entries: IntersectionObserverEntry[]): void {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        this.activateTab(entry.target.id)
      }
    })
  }

  private activateTab(sectionId: string): void {
    this.tabTargets.forEach((tab) => {
      const isActive = tab.getAttribute("aria-controls") === sectionId
      tab.classList.toggle("is-active", isActive)
      tab.setAttribute("aria-selected", String(isActive))
      tab.tabIndex = isActive ? 0 : -1
    })
  }

  private openContainingDetails(section: HTMLElement): void {
    const details = section.closest("details") as HTMLDetailsElement | null
    if (details && !details.open) details.open = true
  }
}
