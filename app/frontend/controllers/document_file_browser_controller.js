import { Controller } from "@hotwired/stimulus"

const querySummaryMaxLength = 28

const kindLabels = {
  all: "すべて",
  visible: "通常",
  grouped: "グループ",
  hidden: "補助",
  debug: "デバッグ",
  other: "その他"
}

const emptyMessages = {
  default: "一致するファイルはありません。",
  query: "検索条件に一致するファイルはありません。",
  kind: "選択した分類に一致するファイルはありません。",
  queryAndKind: "検索条件と分類の両方に一致するファイルはありません。"
}

function summarizeQuery(query) {
  if (query.length <= querySummaryMaxLength) {
    return query
  }

  return `${query.slice(0, querySummaryMaxLength - 3)}...`
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
    const rawQuery = this.queryTarget.value.trim()
    const query = rawQuery.toLowerCase()
    const hasQuery = query.length > 0
    const hasKindFilter = this.activeKind !== "all"
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
      const statusParts = [`${visibleCount}件を表示中`]
      const statusLabelParts = [`${visibleCount}件を表示中`]
      if (hasQuery) {
        statusParts.push(`検索: ${summarizeQuery(rawQuery)}`)
        statusLabelParts.push(`検索: ${rawQuery}`)
      }
      if (!hasQuery || hasKindFilter) {
        statusParts.push(`分類: ${kindLabel}`)
        statusLabelParts.push(`分類: ${kindLabel}`)
      }

      const statusText = statusParts.join(" / ")
      const statusLabel = statusLabelParts.join(" / ")
      this.statusTarget.textContent = statusText
      if (statusText === statusLabel) {
        this.statusTarget.removeAttribute("title")
        this.statusTarget.removeAttribute("aria-label")
      } else {
        this.statusTarget.setAttribute("title", statusLabel)
        this.statusTarget.setAttribute("aria-label", statusLabel)
      }
    }

    if (this.hasEmptyTarget) {
      const emptyMessageKey = hasQuery && hasKindFilter ? "queryAndKind" : hasQuery ? "query" : hasKindFilter ? "kind" : "default"

      this.emptyTarget.textContent = emptyMessages[emptyMessageKey]
      this.emptyTarget.hidden = visibleCount > 0
    }
  }
}
