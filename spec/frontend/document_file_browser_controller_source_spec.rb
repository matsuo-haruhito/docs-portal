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
      expect(controller_source).to include("const queryValue = this.queryTarget.value.trim()")
      expect(controller_source).to include("const query = queryValue.toLowerCase()")
      expect(controller_source).to include('const sectionKind = section.dataset.sectionKind || "all"')
      expect(controller_source).to include('const matchesKind = this.activeKind === "all" || sectionKind === this.activeKind')
      expect(controller_source).to include('const sectionMatchesQuery = query.length > 0 && (section.dataset.sectionSearch || "").toLowerCase().includes(query)')
      expect(controller_source).to include("section.querySelectorAll('[data-document-file-browser-target=\"item\"]')")
      expect(controller_source).to include('const itemMatchesQuery = query.length === 0 || sectionMatchesQuery || (item.dataset.itemSearch || "").toLowerCase().includes(query)')
      expect(controller_source).to include("item.hidden = !visible")
      expect(controller_source).to include("section.hidden = sectionVisibleCount === 0")
    end
  end

  it "keeps status text aligned with query and kind filter context" do
    aggregate_failures do
      expect(controller_source).to include("const kindLabel = kindLabels[this.activeKind] || this.activeKind")
      expect(controller_source).to include("this.statusTarget.textContent = this.statusText(visibleCount, queryValue, kindLabel)")
      expect(controller_source).to include("statusText(visibleCount, queryValue, kindLabel) {")
      expect(controller_source).to include("const hasKindFilter = this.activeKind !== \"all\"")
      expect(controller_source).to include('return `${visibleCount}件を表示中 / 検索: ${queryValue} / 分類: ${kindLabel}`')
      expect(controller_source).to include('return `${visibleCount}件を表示中 / 検索: ${queryValue}`')
      expect(controller_source).to include('return `${visibleCount}件を表示中 / 分類: ${kindLabel}`')
    end
  end

  it "keeps empty-state copy specific to query and kind filter misses" do
    aggregate_failures do
      expect(controller_source).to include("if (this.hasEmptyTarget) {")
      expect(controller_source).to include("this.emptyTarget.textContent = this.emptyMessage(queryValue)")
      expect(controller_source).to include("this.emptyTarget.hidden = visibleCount > 0")
      expect(controller_source).to include("emptyMessage(queryValue) {")
      expect(controller_source).to include("検索条件と分類に一致するファイルはありません。検索語を短くするか、分類を切り替えてください。")
      expect(controller_source).to include("検索条件に一致するファイルはありません。検索語を短くするか、条件を解除してください。")
      expect(controller_source).to include("選択中の分類に一致するファイルはありません。分類を切り替えてください。")
      expect(controller_source).to include("一致するファイルはありません。")
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
