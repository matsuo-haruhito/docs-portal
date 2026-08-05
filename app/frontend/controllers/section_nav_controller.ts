import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]

  declare tabTargets: HTMLAnchorElement[]
  private observer: IntersectionObserver | null = null

  connect(): void {
    this.setupObserver()
    this.bindClicks()
  }

  disconnect(): void {
    this.observer?.disconnect()
    this.observer = null
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
    })
  }

  private bindClicks(): void {
    this.tabTargets.forEach((tab) => {
      tab.addEventListener("click", (event: Event) => this.scrollToSection(event))
    })
  }

  private scrollToSection(event: Event): void {
    event.preventDefault()
    const tab = event.currentTarget as HTMLAnchorElement
    const sectionId = tab.getAttribute("aria-controls")
    const section = sectionId ? document.getElementById(sectionId) : null
    if (!section) return

    const navHeight = this.element.getBoundingClientRect().height
    const top = section.getBoundingClientRect().top + window.scrollY - navHeight
    window.scrollTo({ top, behavior: "smooth" })
  }
}
