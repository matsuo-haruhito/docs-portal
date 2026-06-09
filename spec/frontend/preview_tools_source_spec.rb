require "rails_helper"

RSpec.describe "preview tools source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:controller_source) { read_source("app/frontend/controllers/preview_tools_controller.js") }
  let(:codeblock_controller_source) { read_source("app/frontend/controllers/markdown_preview_codeblock_tools_controller.js") }
  let(:codeblock_tools_source) { read_source("app/frontend/lib/markdown_preview_codeblock_tools.js") }
  let(:csv_controller_source) { read_source("app/frontend/controllers/csv_preview_tools_controller.js") }
  let(:image_controller_source) { read_source("app/frontend/controllers/image_preview_tools_controller.js") }
  let(:pdf_controller_source) { read_source("app/frontend/controllers/pdf_preview_tools_controller.js") }
  let(:pdf_tools_source) { read_source("app/frontend/lib/pdf_preview_tools.js") }
  let(:search_controller_source) { read_source("app/frontend/controllers/markdown_preview_document_search_controller.js") }
  let(:entrypoint_source) { read_source("app/frontend/entrypoints/application.js") }
  let(:layout_source) { read_source("app/views/layouts/application.html.slim") }
  let(:inventory_source) { read_source("doc/frontend_initialization_inventory.md") }

  let(:expected_helpers) do
    {
      "setupMarkdownPreviewTableTools" => "../lib/markdown_preview_table_tools",
      "setupDocumentFileListSearch" => "../lib/document_file_list_search",
      "setupStructuredPreviewTools" => "../lib/structured_preview_tools",
      "setupArchivePreviewTools" => "../lib/archive_preview_tools",
      "setupSiteViewerIframeHeightSync" => "../lib/site_viewer_iframe_height"
    }
  end

  let(:expected_helper_classifications) do
    {
      "setupSiteViewerIframeHeightSync" => "Docusaurus / site viewer iframe",
      "setupMarkdownPreviewTableTools" => "Markdown preview table",
      "setupDocumentFileListSearch" => "document file list search",
      "setupStructuredPreviewTools" => "structured data preview",
      "setupArchivePreviewTools" => "archive preview"
    }
  end

  it "imports the current preview helper bridge set without document search, codeblock, CSV preview, image preview, or PDF preview" do
    aggregate_failures do
      expected_helpers.each do |helper_name, import_path|
        expect(controller_source).to include(%(import { #{helper_name} } from "#{import_path}"))
      end

      expect(controller_source).not_to include("setupMarkdownPreviewDocumentSearch")
      expect(controller_source).not_to include("../lib/markdown_preview_document_search")
      expect(controller_source).not_to include("setupMarkdownPreviewCodeblockTools")
      expect(controller_source).not_to include("../lib/markdown_preview_codeblock_tools")
      expect(controller_source).not_to include("setupCsvPreviewTableTools")
      expect(controller_source).not_to include("../lib/csv_preview_table_tools")
      expect(controller_source).not_to include("setupImagePreviewTools")
      expect(controller_source).not_to include("../lib/image_preview_tools")
      expect(controller_source).not_to include("setupPdfPreviewTools")
      expect(controller_source).not_to include("../lib/pdf_preview_tools")
    end
  end

  it "keeps the inventory classification table aligned with the helper bridge set" do
    aggregate_failures do
      expect(inventory_source).to include("## Preview-tools helper bridge 分類")
      expect(inventory_source).to include("helper 呼び出し順や runtime behavior は変更しません")
      expect(inventory_source).to include("document search は専用 `markdown-preview-document-search` controller へ分離済み")
      expect(inventory_source).to include("Markdown preview codeblock は専用 `markdown-preview-codeblock-tools` controller へ分離済み")
      expect(inventory_source).to include("CSV preview table は専用 `csv-preview-tools` controller へ分離済み")
      expect(inventory_source).to include("image preview は専用 `image-preview-tools` controller へ分離済み")
      expect(inventory_source).to include("PDF preview は専用 `pdf-preview-tools` controller へ分離済み")
      expect(inventory_source).to include("helper 名が docs の分類表・controller import・`refresh()` 呼び出しに揃っている")

      expected_helper_classifications.each do |helper_name, preview_kind|
        expect(inventory_source).to include("| `#{helper_name}` | #{preview_kind} |")
      end

      expect(inventory_source).not_to include("| `setupMarkdownPreviewCodeblockTools` | Markdown preview codeblock |")
      expect(inventory_source).not_to include("| `setupCsvPreviewTableTools` | CSV preview table |")
      expect(inventory_source).not_to include("| `setupImagePreviewTools` | image preview |")
      expect(inventory_source).not_to include("| `setupPdfPreviewTools` | PDF preview |")
    end
  end

  it "refreshes the bridge helpers in the controller lifecycle" do
    refresh_body = controller_source.match(/  refresh\(\) \{\n(?<body>.*?)\n  \}/m)[:body]
    refresh_calls = refresh_body.scan(/^    (setup[A-Za-z0-9]+)\(\)$/).flatten

    expect(refresh_calls).to eq([
      "setupSiteViewerIframeHeightSync",
      "setupMarkdownPreviewTableTools",
      "setupDocumentFileListSearch",
      "setupStructuredPreviewTools",
      "setupArchivePreviewTools"
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

  it "keeps CSV preview tools in a dedicated controller with the same Turbo lifecycle" do
    aggregate_failures do
      expect(csv_controller_source).to include('import { setupCsvPreviewTableTools } from "../lib/csv_preview_table_tools"')
      expect(csv_controller_source.scan("setupCsvPreviewTableTools()").size).to eq(1)
      expect(csv_controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(csv_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(csv_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(csv_controller_source).to include("this.refresh()")
      expect(csv_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(csv_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
    end
  end

  it "keeps image preview tools in a dedicated controller with Turbo lifecycle cleanup" do
    aggregate_failures do
      expect(image_controller_source).to include('import { setupImagePreviewTools } from "../lib/image_preview_tools"')
      expect(image_controller_source.scan("setupImagePreviewTools()").size).to eq(1)
      expect(image_controller_source).to include("this.cleanups = []")
      expect(image_controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(image_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(image_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(image_controller_source).to include("this.refresh()")
      expect(image_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(image_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
      expect(image_controller_source).to include("this.clearImagePreviews()")
    end
  end

  it "keeps PDF preview tools in a dedicated controller with Turbo lifecycle cleanup" do
    aggregate_failures do
      expect(pdf_controller_source).to include('import { setupPdfPreviewTools } from "../lib/pdf_preview_tools"')
      expect(pdf_controller_source.scan("setupPdfPreviewTools()").size).to eq(1)
      expect(pdf_controller_source).to include("this.cleanups = []")
      expect(pdf_controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(pdf_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(pdf_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(pdf_controller_source).to include("this.refresh()")
      expect(pdf_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(pdf_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
      expect(pdf_controller_source).to include("this.clearPdfPreviews()")
      expect(pdf_tools_source).to include('document.addEventListener("keydown", handleKeydown)')
      expect(pdf_tools_source).to include('document.removeEventListener("keydown", handleKeydown)')
      expect(pdf_tools_source).to include("delete container.dataset.pdfPreviewToolsReady")
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

  it "keeps markdown codeblock tools in a dedicated controller with the same Turbo lifecycle" do
    aggregate_failures do
      expect(codeblock_controller_source).to include('import { setupMarkdownPreviewCodeblockTools } from "../lib/markdown_preview_codeblock_tools"')
      expect(codeblock_controller_source.scan("setupMarkdownPreviewCodeblockTools()").size).to eq(1)
      expect(codeblock_controller_source).to include("this.refresh = this.refresh.bind(this)")
      expect(codeblock_controller_source).to include('document.addEventListener("turbo:load", this.refresh)')
      expect(codeblock_controller_source).to include('document.addEventListener("turbo:render", this.refresh)')
      expect(codeblock_controller_source).to include("this.refresh()")
      expect(codeblock_controller_source).to include('document.removeEventListener("turbo:load", this.refresh)')
      expect(codeblock_controller_source).to include('document.removeEventListener("turbo:render", this.refresh)')
      expect(codeblock_tools_source).to include('style[data-docs-portal-codeblock-tools]')
      expect(codeblock_tools_source).to include('frame.dataset.codeblockToolsListenerReady !== "true"')
      expect(codeblock_tools_source).to include("portal-codeblock-warning")
      expect(codeblock_tools_source).to include("addLineAnchors(frameDocument, codeElement, blockId)")
    end
  end

  it "keeps preview controllers registered and attached without direct DOM setup in the entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).to include('import CsvPreviewToolsController from "../controllers/csv_preview_tools_controller"')
      expect(entrypoint_source).to include('import ImagePreviewToolsController from "../controllers/image_preview_tools_controller"')
      expect(entrypoint_source).to include('import MarkdownPreviewCodeblockToolsController from "../controllers/markdown_preview_codeblock_tools_controller"')
      expect(entrypoint_source).to include('import MarkdownPreviewDocumentSearchController from "../controllers/markdown_preview_document_search_controller"')
      expect(entrypoint_source).to include('import PdfPreviewToolsController from "../controllers/pdf_preview_tools_controller"')
      expect(entrypoint_source).to include('import PreviewToolsController from "../controllers/preview_tools_controller"')
      expect(entrypoint_source).to include('application.register("csv-preview-tools", CsvPreviewToolsController)')
      expect(entrypoint_source).to include('application.register("image-preview-tools", ImagePreviewToolsController)')
      expect(entrypoint_source).to include('application.register("markdown-preview-codeblock-tools", MarkdownPreviewCodeblockToolsController)')
      expect(entrypoint_source).to include('application.register("markdown-preview-document-search", MarkdownPreviewDocumentSearchController)')
      expect(entrypoint_source).to include('application.register("pdf-preview-tools", PdfPreviewToolsController)')
      expect(entrypoint_source).to include('application.register("preview-tools", PreviewToolsController)')
      expect(layout_source).to include('data-controller="nav-dropdowns document-tree-navigation manual-document-upload markdown-preview-document-search markdown-preview-codeblock-tools csv-preview-tools image-preview-tools pdf-preview-tools preview-table-resizer preview-tools"')
      expect(entrypoint_source).not_to include("querySelectorAll")
      expect(entrypoint_source).not_to include("addEventListener")
      expect(entrypoint_source).not_to include("new TomSelect")
    end
  end
end
