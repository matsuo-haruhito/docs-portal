import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "changeRegion",
    "changeRequirement",
    "count",
    "query",
    "row",
    "selectedOnly",
    "selectionRequirement",
    "submit",
    "visibleCount"
  ]

  declare readonly hasQueryTarget: boolean
  declare readonly queryTarget: HTMLInputElement
  declare readonly hasSelectedOnlyTarget: boolean
  declare readonly selectedOnlyTarget: HTMLInputElement
  declare readonly rowTargets: HTMLElement[]
  declare readonly countTargets: HTMLElement[]
  declare readonly visibleCountTargets: HTMLElement[]
  declare readonly submitTargets: HTMLButtonElement[]
  declare readonly selectionRequirementTargets: HTMLElement[]
  declare readonly changeRequirementTargets: HTMLElement[]
  declare readonly changeRegionTargets: HTMLElement[]

  connect(): void {
    this.refresh()
  }

  refresh(): void {
    const query = this.hasQueryTarget ? this.normalize(this.queryTarget.value) : ""
    const selectedOnly = this.hasSelectedOnlyTarget && this.selectedOnlyTarget.checked
    let selectedCount = 0
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const checkbox = row.querySelector<HTMLInputElement>('input[name="bulk_edit[document_ids][]"]')
      const selected = Boolean(checkbox && checkbox.checked)
      const searchableText = this.normalize(row.dataset.bulkEditSelectionSearchText || row.textContent || "")
      const visible = searchableText.includes(query) && (!selectedOnly || selected)

      if (selected) selectedCount += 1
      if (visible) visibleCount += 1
      row.hidden = !visible
      row.classList.toggle("bulk-edit-selection__row--selected", selected)
    })

    this.countTargets.forEach((target) => {
      target.textContent = `${selectedCount}件選択中`
    })
    this.visibleCountTargets.forEach((target) => {
      target.textContent = `${visibleCount}件表示中`
    })

    this.refreshSubmissionState(selectedCount > 0, this.hasChanges())
  }

  selectVisible(): void {
    this.setVisibleSelection(true)
  }

  clearVisible(): void {
    this.setVisibleSelection(false)
  }

  private hasChanges(): boolean {
    return this.changeRegionTargets.some((region) => {
      return Array.from(region.querySelectorAll<HTMLInputElement>("input, select, textarea")).some((input) => {
        if (input.disabled) return false
        if (input.type === "checkbox" || input.type === "radio") return input.checked
        return input.value.trim().length > 0
      })
    })
  }

  private refreshSubmissionState(hasSelection: boolean, hasChanges: boolean): void {
    const disabled = !(hasSelection && hasChanges)

    this.submitTargets.forEach((target) => {
      target.disabled = disabled
      target.setAttribute("aria-disabled", disabled.toString())
    })
    this.selectionRequirementTargets.forEach((target) => {
      target.hidden = hasSelection
    })
    this.changeRequirementTargets.forEach((target) => {
      target.hidden = hasChanges
    })
  }

  private setVisibleSelection(checked: boolean): void {
    this.rowTargets.forEach((row) => {
      if (row.hidden) return

      const checkbox = row.querySelector<HTMLInputElement>('input[name="bulk_edit[document_ids][]"]')
      if (checkbox && !checkbox.disabled) checkbox.checked = checked
    })

    this.refresh()
  }

  private normalize(value: string): string {
    return value.toString().trim().toLowerCase()
  }
}
