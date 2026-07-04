require "rails_helper"

RSpec.describe "document file browser source" do
  let(:view_source) { Rails.root.join("app/views/document_versions/show.html.slim").read }
  let(:partial_source) { Rails.root.join("app/views/document_versions/_document_file_list_item.html.slim").read }
  let(:entrypoint_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:controller_source) { Rails.root.join("app/frontend/controllers/document_file_browser_controller.js").read }

  it "wires the version file list to a dedicated stimulus controller" do
    aggregate_failures do
      expect(view_source).to include('data-controller="document-file-browser"')
      expect(view_source).to include('data-document-file-browser-target="query"')
      expect(view_source).to include('input->document-file-browser#filter')
      expect(view_source).to include('document-file-browser#selectKind')
      expect(view_source).to include('data-document-file-browser-target="status"')
      expect(view_source).to include('data-document-file-browser-target="empty"')
      expect(view_source).to include('data-document-file-browser-target="section"')
      expect(view_source).to include('ファイル名・パス・グループ名で絞り込み')
      expect(view_source).to include('README / attachments/spec.pdf / diagrams')
    end
  end

  it "keeps per-file search metadata in the list item partial" do
    aggregate_failures do
      expect(partial_source).to include('- li_options ||= {}')
      expect(partial_source).to include('li *li_options')
    end
  end

  it "registers the stimulus controller from the frontend entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).to include('import DocumentFileBrowserController from "../controllers/document_file_browser_controller"')
      expect(entrypoint_source).to include('application.register("document-file-browser", DocumentFileBrowserController)')
    end
  end

  it "keeps query and classification filtering inside the controller" do
    aggregate_failures do
      expect(controller_source).to include('static targets = ["query", "section", "filterButton", "status", "empty"]')
      expect(controller_source).to include('this.activeKind = "all"')
      expect(controller_source).to include('event.params.kind || "all"')
      expect(controller_source).to include('section.dataset.sectionSearch')
      expect(controller_source).to include('item.dataset.itemSearch')
      expect(controller_source).to include('item.hidden = !visible')
      expect(controller_source).to include('section.hidden = sectionVisibleCount === 0')
      expect(controller_source).to include('button.setAttribute("aria-pressed", String(pressed))')
      expect(controller_source).to include('const hasQuery = query.length > 0')
      expect(controller_source).to include('const hasKindFilter = this.activeKind !== "all"')
      expect(controller_source).to include('const querySummaryMaxLength = 28')
      expect(controller_source).to include('function summarizeQuery(query)')
      expect(controller_source).to include('statusParts.push(`検索: ${summarizeQuery(rawQuery)}`)')
      expect(controller_source).to include('statusLabelParts.push(`検索: ${rawQuery}`)')
      expect(controller_source).to include('this.statusTarget.setAttribute("title", statusLabel)')
      expect(controller_source).to include('this.statusTarget.setAttribute("aria-label", statusLabel)')
      expect(controller_source).to include('if (!hasQuery || hasKindFilter)')
      expect(controller_source).to include('statusParts.push(`分類: ${kindLabel}`)')
      expect(controller_source).to include('this.statusTarget.textContent = statusText')
      expect(controller_source).to include('this.emptyTarget.textContent = emptyMessages[emptyMessageKey]')
    end
  end
end
