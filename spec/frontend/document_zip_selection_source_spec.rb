require "rails_helper"

RSpec.describe "document zip selection source" do
  let(:view_source) { Rails.root.join("app/views/documents/index.html.slim").read }
  let(:entrypoint_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:controller_source) { Rails.root.join("app/frontend/controllers/document_zip_selection_controller.js").read }

  it "wires the project documents zip form to a dedicated stimulus controller" do
    aggregate_failures do
      expect(view_source).to include('data: { controller: "document-zip-selection" }')
      expect(view_source).to include('document_zip_selection_matching_count_value: @selectable_documents_count')
      expect(view_source).to include('data-document-zip-selection-target="count"')
      expect(view_source).to include('document_zip_selection_target: "scopeField"')
      expect(view_source).to include('document_zip_selection_target: "checkbox"')
      expect(view_source).to include('change->document-zip-selection#sync')
      expect(view_source).to include('document-zip-selection#selectPage')
      expect(view_source).to include('document-zip-selection#selectMatching')
      expect(view_source).to include('document-zip-selection#clearSelection')
      expect(view_source).to include('このページを全選択')
      expect(view_source).to include('検索結果#{@selectable_documents_count}件を全選択')
      expect(view_source).to include('選択解除')
    end
  end

  it "registers the stimulus controller from the frontend entrypoint" do
    aggregate_failures do
      expect(entrypoint_source).to include('import DocumentZipSelectionController from "../controllers/document_zip_selection_controller"')
      expect(entrypoint_source).to include('application.register("document-zip-selection", DocumentZipSelectionController)')
    end
  end

  it "keeps matching-selection state and disabled-checkbox guards inside the controller" do
    aggregate_failures do
      expect(controller_source).to include('static targets = ["checkbox", "count", "scopeField"]')
      expect(controller_source).to include('static values = { matchingCount: Number }')
      expect(controller_source).to include('this.matchingSelection = this.scopeFieldTarget.value === "matching"')
      expect(controller_source).to include("selectPage()")
      expect(controller_source).to include("selectMatching()")
      expect(controller_source).to include("clearSelection()")
      expect(controller_source).to include('this.scopeFieldTarget.value = "page"')
      expect(controller_source).to include('this.scopeFieldTarget.value = "matching"')
      expect(controller_source).to include('this.scopeFieldTarget.value = "explicit"')
      expect(controller_source).to include("if (event)")
      expect(controller_source).to include("if (checkbox.disabled) return")
      expect(controller_source).to include('`${this.matchingCountValue}件選択中（検索結果全体）`')
      expect(controller_source).to include('`${count}件選択中`')
    end
  end
end
