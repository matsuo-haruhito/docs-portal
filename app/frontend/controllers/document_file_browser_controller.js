import { Controller } from "@hotwired/stimulus"

const kindLabels = {
  all: "すべて",
  visible: "通常",
  grouped: "グループ",
  hidden: "補助",
  debug: "デバッグ",
  other: "その他"
}

export default class extends Controller {
  static targets = ["query", "section", "filterButton", "status", "empty"]

  connect() {
    this.activeKind = "all"
    this.applyFilters()
  }

  filter() {
    this.applyFilters()
  }

  selectKind(event) {
    this.activeKind = event.params.kind || "all"
    this.applyFilters()
  }

  applyFilters() {
    const query = this.queryTarget.value.trim().toLowerCase()
    let visibleCount = 0

    this.sectionTargets.forEach((section) => {
      const sectionKind = section.dataset.sectionKind || "all"
      const matchesKind = this.activeKind === "all" || sectionKind === this.activeKind
      const sectionMatchesQuery = query.length > 0 && (section.dataset.sectionSearch || "").toLowerCase().includes(query)
      let sectionVisibleCount = 0

      section.querySelectorAll('[data-document-file-browser-target="item"]').forEach((item) => {
        const itemMatchesQuery = query.length === 0 || sectionMatchesQuery || (item.dataset.itemSearch || "").toLowerCase().includes(query)
        const visible = matchesKind && itemMatchesQuery

        item.hidden = !visible
        if (visible) {
          sectionVisibleCount += 1
          visibleCount += 1
        }
      })

      section.hidden = sectionVisibleCount === 0
    })

    if (this.hasFilterButtonTarget) {
      this.filterButtonTargets.forEach((button) => {
        const pressed = (button.dataset.documentFileBrowserKindParam || "all") === this.activeKind
        button.setAttribute("aria-pressed", String(pressed))
      })
    }

    if (this.hasStatusTarget) {
      const kindLabel = kindLabels[this.activeKind] || this.activeKind
      this.statusTarget.textContent = query.length > 0 ? `${visibleCount}件を表示中 / 検索: ${this.queryTarget.value}` : `${visibleCount}件を表示中 / 分類: ${kindLabel}`
    }

    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visibleCount > 0
    }
  }
}
