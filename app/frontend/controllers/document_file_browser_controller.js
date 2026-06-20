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
    const queryValue = this.queryTarget.value.trim()
    const query = queryValue.toLowerCase()
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
      this.statusTarget.textContent = this.statusText(visibleCount, queryValue, kindLabel)
    }

    if (this.hasEmptyTarget) {
      this.emptyTarget.textContent = this.emptyMessage(queryValue)
      this.emptyTarget.hidden = visibleCount > 0
    }
  }

  statusText(visibleCount, queryValue, kindLabel) {
    const hasQuery = queryValue.length > 0
    const hasKindFilter = this.activeKind !== "all"

    if (hasQuery && hasKindFilter) {
      return `${visibleCount}件を表示中 / 検索: ${queryValue} / 分類: ${kindLabel}`
    }

    if (hasQuery) {
      return `${visibleCount}件を表示中 / 検索: ${queryValue}`
    }

    return `${visibleCount}件を表示中 / 分類: ${kindLabel}`
  }

  emptyMessage(queryValue) {
    const hasQuery = queryValue.length > 0
    const hasKindFilter = this.activeKind !== "all"

    if (hasQuery && hasKindFilter) {
      return "検索条件と分類に一致するファイルはありません。検索語を短くするか、分類を切り替えてください。"
    }

    if (hasQuery) {
      return "検索条件に一致するファイルはありません。検索語を短くするか、条件を解除してください。"
    }

    if (hasKindFilter) {
      return "選択中の分類に一致するファイルはありません。分類を切り替えてください。"
    }

    return "一致するファイルはありません。"
  }
}
