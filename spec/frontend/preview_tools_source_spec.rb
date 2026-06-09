require "rails_helper"

RSpec.describe "preview tools source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:controller_source) { read_source("app/frontend/controllers/preview_tools_controller.js") }
  let(:search_controller_source) { read_source("app/frontend/controllers/markdown_preview_document_search_controller.js") }
  let(:entrypoint_source) { read_source("app/frontend/entrypoints/application.js") }
  let(:layout_source) { read_source("app/views/layouts/application.html.slim") }
  let(:inventory_source) { read_source("doc/frontend_initialization_inventory.md") }

  let(:expected_helpers) do
    {
      "setupMarkdownPreviewTableTools" => "../lib/markdown_preview_table_tools",
      "setupMarkdownPreviewCodeblockTools" => "../lib/markdown_preview_codeblock_tools",
      "setupDocumentFileListSearch" => "../lib/document_file_list_search",
      "setupCsvPreviewTableTools" => "../lib/csv_preview_table_tools",
      "setupStructuredPreviewTools" => "../lib/structured_preview_tools",
      "setupArchivePreviewTools" => "../lib/archive_preview_tools",
      "setupImagePreviewTools" => "../lib/image_preview_tools",
      "setupPdfPreviewTools" => "../lib/pdf_preview_tools",
      "setupSiteViewerIframeHeightSync" => "../lib/site_viewer_iframe_height"
    }
  end

  let(:expected_helper_classifications) do
    {
      "setupSiteViewerIframeHeightSync" => "Docusaurus / site viewer iframe",
      "setupMarkdownPreviewTableTools" => "Markdown preview table",
      "setupMarkdownPreviewCodeblockTools" => "Markdown preview codeblock",
      "setupDocumentFileListSearch" => "document file list search",
      "setupCsvPreviewTableTools" => "CSV preview table",
      "setupStructuredPreviewTools" => "structured data preview",
      "setupArchivePreviewTools" => "archive preview",
      "setupImagePreviewTools" => "image preview",
      "setupPdfPreviewTools" => "PDF preview"
    }
  end

  it "imports the current preview helper bridge set without document search" do
    aggregate_failures do
      expected_helpers.each do |helper_name, import_path|
        expect(controller_source).to include(%(import { #{helper_name} } from "#{import_path}"))
      end

      expect(controller_source).not_to include("setupMarkdownPreviewDocumentSearch")
      expect(controller_source).not_to include("../lib/markdown_preview_document_search")
    end
  end

  it "keeps the inventory classification table aligned with the helper bridge set" do
    aggregate_failures do
      expect(inventory_source).to include("## Preview-tools helper bridge 分類")
      expect(inventory_source).to include("helper 呼び出し順や runtime behavior は変更しません")
      expect(inventory_source).to include("document search は専用 `markdown-preview-document-search` controller へ分離済み")
      expect(inventory_source).to include("helper 名が docs の分類表・controller import・`refresh()` 呼び出しに揃っている")

      expected_helper_classifications.each do |helper_name, preview_kind|
        expect(inventory_source).to include("| `#{helper_name}` | #{preview_kind} |")
      end
    end
  end

  it "refreshes the bridge helpers in the controller lifecycle" do
    refresh_body = controller_source.match(/  refresh\(\) \{\n(?<body>.*?)\n  \}/m)[:body]
    refresh_calls = refresh_body.scan(/^    (setup[A-Za-z0-9]+)\(\)$/).flatten

    expect(refresh_calls).to eq([
      "setupSiteViewerIframeHeightSync",
      "setupMarkdownPreviewTableTools",
      "setupMarkdownPreviewCodeblockTools",
      "setupDocumentFileListSearch",
      "setupCsvPreviewTableTools",
      "setupStructuredPreviewTools",
      "setupArchivePreviewTools",
      "setupImagePreviewTools",
      "setupPdfPreviewTools"
    ])
  end

  it "re-runs refresh after Turbo page changes and removes those listeners on disconnect" do
    aggregate_failures do
      expect(controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(controller_source).to include("this.refresh()")
      expect(controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
    end
  end

  it "keeps document search in a dedicated controller with the same Turbo lifecycle" do
    aggregate_failures do
      expect(search_controller_source).to include('import { setupMarkdownPreviewDocumentSearch } from "../lib/markdown_preview_document_search"')
      expect(search_controller_source.scan("setupMarkdownPreviewDocumentSearch()").size).to eq(1)
      expect(search_controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(search_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(search_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(search_controller_source).to include("this.refresh()")
      expect(search_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(search_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
    end
  end

  it "keeps preview controllers registered and attached without direct DOM setup in the entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).to include('import MarkdownPreviewDocumentSearchController from "../controllers/markdown_preview_document_search_controller"')
      expect(entrypoint_source).to include('import PreviewToolsController from "../controllers/preview_tools_controller"')
      expect(entrypoint_source).to include('application.register("markdown-preview-document-search", MarkdownPreviewDocumentSearchController)')
      expect(entrypoint_source).to include('application.register("preview-tools", PreviewToolsController)')
      expect(layout_source).to include('data-controller="nav-dropdowns document-tree-navigation manual-document-upload markdown-preview-document-search preview-table-resizer preview-tools"')
      expect(entrypoint_source).not_to include("querySelectorAll")
      expect(entrypoint_source).not_to include("addEventListener")
      expect(entrypoint_source).not_to include("new TomSelect")
    end
  end
end
