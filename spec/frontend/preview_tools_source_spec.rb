require "rails_helper"

RSpec.describe "preview tools source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:controller_source) { read_source("app/frontend/controllers/preview_tools_controller.js") }
  let(:entrypoint_source) { read_source("app/frontend/entrypoints/application.js") }

  let(:expected_helpers) do
    {
      "setupMarkdownPreviewTableTools" => "../lib/markdown_preview_table_tools",
      "setupMarkdownPreviewCodeblockTools" => "../lib/markdown_preview_codeblock_tools",
      "setupMarkdownPreviewDocumentSearch" => "../lib/markdown_preview_document_search",
      "setupDocumentFileListSearch" => "../lib/document_file_list_search",
      "setupCsvPreviewTableTools" => "../lib/csv_preview_table_tools",
      "setupStructuredPreviewTools" => "../lib/structured_preview_tools",
      "setupArchivePreviewTools" => "../lib/archive_preview_tools",
      "setupImagePreviewTools" => "../lib/image_preview_tools",
      "setupPdfPreviewTools" => "../lib/pdf_preview_tools",
      "setupSiteViewerIframeHeightSync" => "../lib/site_viewer_iframe_height"
    }
  end

  it "imports the current preview helper bridge set" do
    aggregate_failures do
      expected_helpers.each do |helper_name, import_path|
        expect(controller_source).to include(%(import { #{helper_name} } from "#{import_path}"))
      end
    end
  end

  it "refreshes the bridge helpers in the controller lifecycle" do
    refresh_body = controller_source.match(/  refresh\(\) \{\n(?<body>.*?)\n  \}/m)[:body]
    refresh_calls = refresh_body.scan(/^    (setup[A-Za-z0-9]+)\(\)$/).flatten

    expect(refresh_calls).to eq([
      "setupSiteViewerIframeHeightSync",
      "setupMarkdownPreviewDocumentSearch",
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

  it "keeps preview-tools registered through the frontend entrypoint without direct DOM setup there" do
    aggregate_failures do
      expect(entrypoint_source).to include('import PreviewToolsController from "../controllers/preview_tools_controller"')
      expect(entrypoint_source).to include('application.register("preview-tools", PreviewToolsController)')
      expect(entrypoint_source).not_to include("querySelectorAll")
      expect(entrypoint_source).not_to include("addEventListener")
      expect(entrypoint_source).not_to include("new TomSelect")
    end
  end
end
