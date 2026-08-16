import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  private onToggle!: (event: Event) => void
  private onClick!: (event: MouseEvent) => void
  private onKeydown!: (event: KeyboardEvent) => void

  connect(): void {
    this.onToggle = (event: Event) => {
      const dropdown = (event.target as Element).closest?.("[data-nav-dropdown]") as HTMLDetailsElement | null
      if (!dropdown || !dropdown.open) return
      this.closeOpenDropdowns(dropdown)
    }
    this.onClick = (event: MouseEvent) => {
      const clickedDropdown = (event.target as Element).closest?.("[data-nav-dropdown]")
      if (clickedDropdown) return
      this.closeOpenDropdowns()
    }
    this.onKeydown = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return
      const dropdownToRestoreFocus = (event.target as Element).closest?.("[data-nav-dropdown][open]") || this.openDropdowns[0]
      this.closeOpenDropdowns()
      this.restoreDropdownSummaryFocus(dropdownToRestoreFocus as HTMLElement | undefined)
    }

    document.addEventListener("toggle", this.onToggle, true)
    document.addEventListener("click", this.onClick as EventListener)
    document.addEventListener("keydown", this.onKeydown as EventListener)
  }

  disconnect(): void {
    document.removeEventListener("toggle", this.onToggle, true)
    document.removeEventListener("click", this.onClick as EventListener)
    document.removeEventListener("keydown", this.onKeydown as EventListener)
  }

  private closeOpenDropdowns(exceptDropdown: Element | null = null): void {
    this.openDropdowns.forEach((dropdown) => {
      if (dropdown !== exceptDropdown) (dropdown as HTMLDetailsElement).open = false
    })
  }

  private restoreDropdownSummaryFocus(dropdown: HTMLElement | undefined): void {
    const summary = dropdown?.querySelector?.("summary.nav-dropdown__summary") as HTMLElement | null
    summary?.focus?.()
  }

  private get openDropdowns(): NodeListOf<Element> {
    return this.element.querySelectorAll("[data-nav-dropdown][open]")
  }
}
