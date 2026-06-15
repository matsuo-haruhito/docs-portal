require "rails_helper"

RSpec.describe "Admin document set filter accessibility", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "A11y Project") }
  let!(:document) { create(:document, project:, title: "アクセシビリティ仕様", slug: "a11y-spec") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def document_filter_status
    parsed_html.at_css('[data-document-set-document-filter-target~="status"]')
  end

  def document_filter_empty_state
    parsed_html.at_css('[data-document-set-document-filter-target~="empty"]')
  end

  def remote_document_picker
    parsed_html.at_css('select[name="document_set_remote_document_id"]')
  end

  def document_row
    parsed_html.at_css(%(tr[data-document-set-document-filter-document-id="#{document.id}"]))
  end

  it "exposes live filter status while preserving document picker and selected row inputs" do
    sign_in_as(admin)

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "filter accessibility render",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)

    status = document_filter_status
    expect(status).to be_present
    expect(status["role"]).to eq("status")
    expect(status["aria-live"]).to eq("polite")
    expect(status["aria-atomic"]).to eq("true")

    empty_state = document_filter_empty_state
    expect(empty_state).to be_present
    expect(empty_state.attribute("hidden")).to be_present
    expect(empty_state["aria-live"]).to eq("polite")
    expect(empty_state["aria-atomic"]).to eq("true")

    picker = remote_document_picker
    expect(picker).to be_present
    expect(picker["data-action"]).to include("rails-fields-kit--tom-select:change->document-set-document-filter#pickRemoteDocument")

    row = document_row
    expect(row).to be_present
    expect(row["data-document-set-document-filter-search-text"]).to include("アクセシビリティ仕様", "a11y-spec")
    expect(row.at_css(%(input[name^="document_set_items"][value="#{document.id}"]))).to be_present
  end
end
