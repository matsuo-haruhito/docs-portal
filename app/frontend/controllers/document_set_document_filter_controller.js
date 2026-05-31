import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "row", "status"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.normalize(this.queryTarget.value)
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const searchableText = this.normalize(row.dataset.documentSetDocumentFilterSearchText || row.textContent)
      const visible = query === "" || searchableText.includes(query)
      row.hidden = !visible
      if (visible) visibleCount += 1
    })

    this.statusTargets.forEach((status) => {
      status.textContent = query === "" ? `${this.rowTargets.length}件表示中` : `${visibleCount}件表示中`
    })
  }

  normalize(value) {
    return value.toString().trim().toLowerCase()
  }
}
