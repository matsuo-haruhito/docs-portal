require "rails_helper"

RSpec.describe "preview tools source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:markdown_table_controller_source) { read_source("app/frontend/controllers/markdown_preview_table_tools_controller.js") }
  let(:table_tools_source) { read_source("app/frontend/lib/markdown_preview_table_tools.js") }
  let(:document_search_source) { read_source("app/frontend/lib/markdown_preview_document_search.js") }
  let(:entrypoint_source) { read_source("app/frontend/entrypoints/application.js") }
  let(:layout_source) { read_source("app/views/layouts/application.html.slim") }
  let(:inventory_source) { read_source("doc/frontend_initialization_inventory.md") }
  let(:roadmap_source) { read_source("ROADMAP.md") }

  let(:dedicated_preview_controllers) do
    {
      "archive-preview-tools" => ["ArchivePreviewToolsController", "archive_preview_tools_controller"],
      "csv-preview-tools" => ["CsvPreviewToolsController", "csv_preview_tools_controller"],
      "document-file-list-search" => ["DocumentFileListSearchController", "document_file_list_search_controller"],
      "image-preview-tools" => ["ImagePreviewToolsController", "image_preview_tools_controller"],
      "markdown-preview-codeblock-tools" => ["MarkdownPreviewCodeblockToolsController", "markdown_preview_codeblock_tools_controller"],
      "markdown-preview-document-search" => ["MarkdownPreviewDocumentSearchController", "markdown_preview_document_search_controller"],
      "markdown-preview-table-tools" => ["MarkdownPreviewTableToolsController", "markdown_preview_table_tools_controller"],
      "pdf-preview-tools" => ["PdfPreviewToolsController", "pdf_preview_tools_controller"],
      "site-viewer-iframe-height" => ["SiteViewerIframeHeightController", "site_viewer_iframe_height_controller"],
      "structured-preview-tools" => ["StructuredPreviewToolsController", "structured_preview_tools_controller"]
    }
  end

  let(:registered_controller_identifiers) do
    entrypoint_source.scan(/application\.register\("([^"]+)"/).flatten
  end

  it "moves the markdown preview table helper to a dedicated controller with the existing Turbo lifecycle" do
    aggregate_failures do
      expect(markdown_table_controller_source).to include('import { setupMarkdownPreviewTableTools } from "../lib/markdown_preview_table_tools"')
      expect(markdown_table_controller_source.scan("setupMarkdownPreviewTableTools()").size).to eq(1)
      expect(markdown_table_controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(markdown_table_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(markdown_table_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(markdown_table_controller_source).to include("this.refresh()")
      expect(markdown_table_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(markdown_table_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
    end
  end

  it "removes the old preview-tools bridge from the registered and attached controller set" do
    aggregate_failures do
      expect(Rails.root.join("app/frontend/controllers/preview_tools_controller.js")).not_to exist
      expect(entrypoint_source).not_to include('from "../controllers/preview_tools_controller"')
      expect(entrypoint_source).not_to include('application.register("preview-tools"')
      expect(layout_source).not_to include(" preview-tools")
      expect(layout_source).not_to include('data-controller="preview-tools')
    end
  end

  it "keeps preview controllers registered and attached without direct DOM setup in the entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).to include('import "@hotwired/turbo-rails"')
      expect(entrypoint_source).to include("import { Application } from \"@hotwired/stimulus\"")
      expect(entrypoint_source).to include("const application = Application.start()")
      expect(entrypoint_source).to include("import { RailsTablePreferencesController } from \"rails_table_preferences\"")
      expect(entrypoint_source).to include("import { TomSelectController } from \"rails_fields_kit\"")
      expect(entrypoint_source).to include('application.register("rails-table-preferences", RailsTablePreferencesController)')
      expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", TomSelectController)')

      dedicated_preview_controllers.each do |identifier, (constant_name, source_name)|
        expect(entrypoint_source).to include(%(import #{constant_name} from "../controllers/#{source_name}"))
        expect(entrypoint_source).to include(%(application.register("#{identifier}", #{constant_name})))
        expect(layout_source).to include(identifier)
      end

      expect(entrypoint_source).not_to include("querySelectorAll")
      expect(entrypoint_source).not_to include("document.querySelector")
      expect(entrypoint_source).not_to include("addEventListener")
      expect(entrypoint_source).not_to include('addEventListener("turbo:load"')
      expect(entrypoint_source).not_to include('addEventListener("turbo:render"')
      expect(entrypoint_source).not_to include("new TomSelect")
    end
  end

  it "keeps every registered controller represented in the frontend initialization inventory" do
    aggregate_failures do
      expect(registered_controller_identifiers).to include(
        "rails-table-preferences",
        "rails-fields-kit--tom-select",
        "markdown-preview-table-tools"
      )

      registered_controller_identifiers.each do |identifier|
        expect(inventory_source).to include("`#{identifier}`")
      end

      expect(inventory_source).to include("Source-level guard 済みの controller")
      expect(inventory_source).to include("`application.js` の直接 DOM setup は追加しない")
      expect(inventory_source).to include("app 側 `new TomSelect(...)` は追加しない")
    end
  end

  it "keeps the markdown document search visible copy and state source boundaries unchanged" do
    aggregate_failures do
      expect(document_search_source).to include("portal-document-search-bar")
      expect(document_search_source).to include("portal-document-search-toggle")
      expect(document_search_source).to include("portal-document-search-controls")
      expect(document_search_source).to include("portal-document-search-count")
      expect(document_search_source).to include('bar.className = "portal-document-search-bar is-collapsed"')
      expect(document_search_source).to include('bar.classList.remove("is-collapsed")')
      expect(document_search_source).to include('bar.classList.add("is-collapsed")')
      expect(document_search_source).to include('toggleButton.textContent = "文書内検索 /"')
      expect(document_search_source).to include('toggleButton.textContent = "検索を閉じる"')
      expect(document_search_source).to include('label.textContent = "この文書内を検索"')
      expect(document_search_source).to include('input.setAttribute("aria-label", "この文書内を検索")')
      expect(document_search_source).to include('input.placeholder = "キーワード"')
      expect(document_search_source).to include('count.textContent = query.length > 0 ? "2文字以上" : ""')
      expect(document_search_source).to include('count.textContent = `${matchCount}件`')
      expect(document_search_source).to include('count.textContent = `${state.currentIndex + 1}/${marks.length}`')
      expect(document_search_source).to include('previousButton.textContent = "前へ"')
      expect(document_search_source).to include('nextButton.textContent = "次へ"')
      expect(document_search_source).to include('clearButton.textContent = "クリア"')
      expect(document_search_source).to include('parent.closest("script, style, nav, footer, aside, .portal-document-search-bar")')
      expect(document_search_source.scan("Cross-origin fallback: keep the viewer usable even if document search cannot be injected.").size).to eq(2)
    end
  end

  it "keeps the inventory aligned with the registered preview controller set" do
    aggregate_failures do
      dedicated_preview_controllers.each_key do |identifier|
        expect(inventory_source).to include("`#{identifier}`")
      end

      expect(inventory_source).to include("`preview-tools` bridge は空 bridge を残さず退役")
      expect(inventory_source).to include("`app/frontend/entrypoints/application.js` は `preview-tools` を登録しない")
      expect(inventory_source).to include("`app/views/layouts/application.html.slim` は `preview-tools` を attach しない")
      expect(inventory_source).to include("Source-level guard は `spec/frontend/preview_tools_source_spec.rb`")
      expect(inventory_source).to include("`application.js` の直接 DOM setup は追加しない")
      expect(inventory_source).to include("app 側 `new TomSelect(...)` は追加しない")
    end
  end

  it "keeps ROADMAP aligned with the retired preview-tools bridge boundary" do
    aggregate_failures do
      expect(roadmap_source).to include("`preview-tools` bridge は移行用の入口として退役済み")
      expect(roadmap_source).to include("bridge 再導入や空 controller の維持は current support として扱わない")
      expect(roadmap_source).to include("専用 controller がそれぞれ helper refresh を担当")
      expect(roadmap_source).to include("`markdown-preview-table-tools`")
      expect(roadmap_source).to include("`pdf-preview-tools`")
      expect(roadmap_source).to include("`application.js` に `querySelectorAll` とイベント登録を直接増やさない")
      expect(roadmap_source).not_to include("`preview-tools` は `setupXxx()` helper 群を Stimulus controller から refresh する bridge として維持する")
    end
  end

  it "keeps markdown table preference persistence source boundaries unchanged" do
    aggregate_failures do
      expect(table_tools_source).to include('const TABLE_PREFERENCE_COLLECTION_PATH = "/rails_table_preferences/preferences"')
      expect(table_tools_source).to include("function preferenceCollectionUrl(tableKey)")
      expect(table_tools_source).to include("return `${TABLE_PREFERENCE_COLLECTION_PATH}/${encodeURIComponent(tableKey)}`")
      expect(table_tools_source).to include('function preferencePresetUrl(tableKey, name = "default")')
      expect(table_tools_source).to include("return `${preferenceCollectionUrl(tableKey)}/${encodeURIComponent(name)}`")
      expect(table_tools_source).to include("function csrfToken()")
      expect(table_tools_source).to include(%(document.querySelector("meta[name='csrf-token']")?.content || ""))
      expect(table_tools_source).to include('"X-CSRF-Token": csrfToken()')
      expect(table_tools_source).to include('method: "PATCH"')
      expect(table_tools_source).to include("if (patchResponse.status !== 404) throw new Error(`Failed to save table preferences: ${patchResponse.status}`)")
      expect(table_tools_source).to include('method: "POST"')
      expect(table_tools_source).to include('body: JSON.stringify({ name: "default", settings })')
      expect(table_tools_source).to include("if (response.status === 404) return null")
      expect(table_tools_source).to include("if (!payload) return")
      expect(table_tools_source).to include("const tableKey = table.dataset.railsTablePreferencesTableKey")
      expect(table_tools_source).to include("if (!tableKey) return")
      expect(table_tools_source).to include('if (wrapper.dataset.tableSearchReady === "true") return')
      expect(table_tools_source).to include('wrapper.dataset.tableSearchReady = "true"')
      expect(table_tools_source).to include("installPreferencePanel(frameDocument, table, displayGroup, copyStatus)")
    end
  end

  it "keeps inventory aligned with the dedicated markdown table controller boundary" do
    aggregate_failures do
      expect(inventory_source).to include("`markdown-preview-table-tools`")
      expect(inventory_source).to include("`setupMarkdownPreviewTableTools()` を専用 controller から refresh")
      expect(inventory_source).to include("`preview-tools` bridge は空 bridge を残さず退役")
      expect(inventory_source).to include("#475 の full `rails_table_preferences` 統合")
      expect(inventory_source).to include("Markdown preview table の full `rails_table_preferences` 統合、column visibility / preset UI、Docusaurus renderer、DOM rewrite、preference schema / key 再設計は変更しない")
    end
  end
end
