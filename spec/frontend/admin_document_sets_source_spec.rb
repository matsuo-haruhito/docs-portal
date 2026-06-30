require "rails_helper"

RSpec.describe "admin/document_sets form source" do
  let(:view_source) { Rails.root.join("app/views/admin/document_sets/_form.html.slim").read }
  let(:controller_source) { Rails.root.join("app/frontend/controllers/document_set_document_filter_controller.js").read }
  let(:css_source) { Rails.root.join("app/frontend/entrypoints/document_set_document_filter.css").read }

  it "keeps document set item field names while adding selection filter hooks" do
    expect(view_source).to include("document_set_items[\#{index}][document_id]")
    expect(view_source).to include("document_set_items[\#{index}][selected]")
    expect(view_source).to include("document_set_items[\#{index}][document_version_id]")
    expect(view_source).to include("document_set_items[\#{index}][sort_order]")
    expect(view_source).to include("document_set_items[\#{index}][note]")
    expect(view_source).to include("data-controller=\"document-set-document-filter\"")
    expect(view_source).to include("data-document-set-document-filter-target=\"selectedOnly\"")
    expect(view_source).to include("data-document-set-document-filter-target=\"empty\"")
    expect(view_source).to include("class: \"document-set-document-filter__checkbox\"")
  end

  it "updates visible rows, selected count, and empty state without remote search" do
    expect(controller_source).to include("static targets = [\"query\", \"row\", \"status\", \"checkbox\", \"selectedOnly\", \"empty\", \"tableBody\"]")
    expect(controller_source).to include("const selectedOnly = this.hasSelectedOnlyTarget && this.selectedOnlyTarget.checked")
    expect(controller_source).to include("row.hidden = !visible")
    expect(controller_source).to include("row.classList.toggle(\"is-selected\", selected)")
    expect(controller_source).to include("選択済み ${selectedCount}件 / 全${totalCount}件")
    expect(controller_source).to include("検索条件に一致する文書はありません。")
    expect(controller_source).not_to include("fetch(")
  end

  it "styles selected rows and the progressive empty state only within this component" do
    expect(css_source).to include(".document-set-document-filter__selected-only")
    expect(css_source).to include(".document-set-document-filter__empty")
    expect(css_source).to include("tr.document-set-document-filter__row.is-selected")
  end
end
