require "rails_helper"

RSpec.describe "Admin document set document picker cue", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Picker Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def remote_document_picker
    parsed_html.at_css('select[name="document_set_remote_document_id"]')
  end

  it "shows the remote search boundary cue without changing the local filter controls" do
    create(:document, project:, title: "対象文書", slug: "target-doc")
    sign_in_as(admin)

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "picker cue render",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("文書名 / URL識別子で探す")
    expect(page_text).to include("検索語は最大#{Admin::DocumentSetsController::DOCUMENT_SEARCH_QUERY_MAX_LENGTH}文字、候補は最大#{Admin::DocumentSetsController::DOCUMENT_SEARCH_LIMIT}件です。")
    expect(page_text).to include("下の絞り込み欄は表示中の対象文書だけを絞ります。")
    expect(page_text).to include("表示中の対象文書を絞り込み")

    picker = remote_document_picker
    expect(picker).to be_present
    expect(picker["data-rails-fields-kit--tom-select-query-param-value"]).to eq("q")
    expect(picker["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentSetsController::DOCUMENT_SEARCH_LIMIT.to_s)

    local_filter = parsed_html.at_css("#document-set-document-filter-query")
    expect(local_filter).to be_present
    expect(local_filter["placeholder"]).to eq("文書名またはURL識別子")
    expect(local_filter["data-action"]).to include("input->document-set-document-filter#filter")
  end
end
