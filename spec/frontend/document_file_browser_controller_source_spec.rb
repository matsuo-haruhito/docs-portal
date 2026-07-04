require "rails_helper"

RSpec.describe "document-file-browser controller source" do
  let(:controller_source) { Rails.root.join("app/frontend/controllers/document_file_browser_controller.js").read }
  let(:entrypoint_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:inventory_source) { Rails.root.join("doc/frontend_initialization_inventory.md").read }

  it "keeps the controller registered without adding direct entrypoint DOM setup" do
    aggregate_failures do
      expect(entrypoint_source).to include('import DocumentFileBrowserController from "../controllers/document_file_browser_controller"')
      expect(entrypoint_source).to include('application.register("document-file-browser", DocumentFileBrowserController)')
      expect(entrypoint_source).not_to include("querySelectorAll")
      expect(entrypoint_source).not_to include("addEventListener")
      expect(entrypoint_source).not_to include("new TomSelect")
    end
  end

  it "keeps the target set and default initialization stable" do
    aggregate_failures do
      expect(controller_source).to include('static targets = ["query", "section", "filterButton", "status", "empty"]')
      expect(controller_source).to include("connect() {\n    this.activeKind = \"all\"\n    this.applyFilters()\n  }")
      expect(controller_source).to include("filter() {\n    this.applyFilters()\n  }")
    end
  end

  it "keeps kind selection tied to Stimulus params and aria-pressed state" do
    aggregate_failures do
      expect(controller_source).to include("selectKind(event) {\n    this.activeKind = event.params.kind || \"all\"\n    this.applyFilters()\n  }")
      expect(controller_source).to include("if (this.hasFilterButtonTarget) {")
      expect(controller_source).to include('const pressed = (button.dataset.documentFileBrowserKindParam || "all") === this.activeKind')
      expect(controller_source).to include('button.setAttribute("aria-pressed", String(pressed))')
    end
  end

  it "keeps section and item search matching boundaries readable" do
    aggregate_failures do
      expect(controller_source).to include("const rawQuery = this.queryTarget.value.trim()")
      expect(controller_source).to include("const query = rawQuery.toLowerCase()")
      expect(controller_source).to include('const sectionKind = section.dataset.sectionKind || "all"')
      expect(controller_source).to include('const matchesKind = this.activeKind === "all" || sectionKind === this.activeKind')
      expect(controller_source).to include('const sectionMatchesQuery = query.length > 0 && (section.dataset.sectionSearch || "").toLowerCase().includes(query)')
      expect(controller_source).to include("section.querySelectorAll('[data-document-file-browser-target=\"item\"]')")
      expect(controller_source).to include('const itemMatchesQuery = query.length === 0 || sectionMatchesQuery || (item.dataset.itemSearch || "").toLowerCase().includes(query)')
      expect(controller_source).to include("item.hidden = !visible")
      expect(controller_source).to include("section.hidden = sectionVisibleCount === 0")
    end
  end

  it "keeps long query status summaries readable without dropping the full query" do
    aggregate_failures do
      expect(controller_source).to include("const querySummaryMaxLength = 28")
      expect(controller_source).to include("function summarizeQuery(query) {")
      expect(controller_source).to include("if (query.length <= querySummaryMaxLength) {")
      expect(controller_source).to include("return `${query.slice(0, querySummaryMaxLength - 3)}...`")
      expect(controller_source).to include("statusParts.push(`検索: ${summarizeQuery(rawQuery)}`)")
      expect(controller_source).to include("statusLabelParts.push(`検索: ${rawQuery}`)")
      expect(controller_source).to include('this.statusTarget.setAttribute("title", statusLabel)')
      expect(controller_source).to include('this.statusTarget.setAttribute("aria-label", statusLabel)')
      expect(controller_source).to include('this.statusTarget.removeAttribute("title")')
      expect(controller_source).to include('this.statusTarget.removeAttribute("aria-label")')
    end
  end

  it "keeps status and empty-state text boundaries stable" do
    aggregate_failures do
      expect(controller_source).to include("const kindLabel = kindLabels[this.activeKind] || this.activeKind")
      expect(controller_source).to include("const statusParts = [`${visibleCount}件を表示中`]")
      expect(controller_source).to include("const statusLabelParts = [`${visibleCount}件を表示中`]")
      expect(controller_source).to include("if (!hasQuery || hasKindFilter) {")
      expect(controller_source).to include("statusParts.push(`分類: ${kindLabel}`)")
      expect(controller_source).to include('const statusText = statusParts.join(" / ")')
      expect(controller_source).to include('const statusLabel = statusLabelParts.join(" / ")')
      expect(controller_source).to include("this.statusTarget.textContent = statusText")
      expect(controller_source).to include("if (this.hasEmptyTarget) {")
      expect(controller_source).to include("this.emptyTarget.hidden = visibleCount > 0")
    end
  end

  it "keeps empty-state reasons aligned with query and kind filters" do
    aggregate_failures do
      expect(controller_source).to include('query: "検索条件に一致するファイルはありません。"')
      expect(controller_source).to include('kind: "選択した分類に一致するファイルはありません。"')
      expect(controller_source).to include('queryAndKind: "検索条件と分類の両方に一致するファイルはありません。"')
      expect(controller_source).to include('const hasQuery = query.length > 0')
      expect(controller_source).to include('const hasKindFilter = this.activeKind !== "all"')
      expect(controller_source).to include('const emptyMessageKey = hasQuery && hasKindFilter ? "queryAndKind" : hasQuery ? "query" : hasKindFilter ? "kind" : "default"')
      expect(controller_source).to include("this.emptyTarget.textContent = emptyMessages[emptyMessageKey]")
    end
  end

  it "keeps the frontend inventory aligned with this source guard" do
    aggregate_failures do
      expect(inventory_source).to include("`document-file-browser` | `spec/frontend/document_file_browser_controller_source_spec.rb`")
      expect(inventory_source).to include("kind / query filter、section / item search、status text、empty state")
      expect(inventory_source).to include("版詳細の添付・元ファイル browser UI redesign")
    end
  end
end
