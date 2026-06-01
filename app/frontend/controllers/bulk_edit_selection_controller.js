import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "query", "row", "selectedOnly", "visibleCount"]

  connect() {
    this.refresh()
  }

  refresh() {
    const query = this.hasQueryTarget ? this.normalize(this.queryTarget.value) : ""
    const selectedOnly = this.hasSelectedOnlyTarget && this.selectedOnlyTarget.checked
    let selectedCount = 0
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const checkbox = row.querySelector('input[name="bulk_edit[document_ids][]"]')
      const selected = Boolean(checkbox && checkbox.checked)
      const searchableText = this.normalize(row.dataset.bulkEditSelectionSearchText || row.textContent)
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
  }

  normalize(value) {
    return value.toString().trim().toLowerCase()
  }
}
