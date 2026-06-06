require "rails_helper"

RSpec.describe "Document manual upload destination", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "UPLOADDEST", name: "Upload Destination Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows a compact selected folder label while keeping the full upload path available" do
    sign_in_as(internal_user)
    selected_path = "docs/product/releases/2026/q2/customer-guides"

    get project_documents_path(project, upload_source_path: selected_path)

    expect(response).to have_http_status(:ok)
    panel = parsed_html.at_css(".manual-document-upload-panel")
    expect(panel).to be_present
    expect(panel["data-manual-document-upload-source-path-value"]).to eq(selected_path)
    expect(panel.at_css(".manual-document-upload-panel__destination")).to be_present
    expect(panel.at_css(".manual-document-upload-panel__destination-name").text.squish).to eq("customer-guides")
    expect(panel.at_css(".manual-document-upload-panel__destination-name")["title"]).to eq(selected_path)
    expect(panel.at_css(".manual-document-upload-panel__destination-path").text.squish).to eq(selected_path)
    expect(panel.at_css(".manual-document-upload-panel__destination-path")["title"]).to eq(selected_path)
    expect(page_text).to include("ここにドロップすると、上記パス直下の追加候補としてアップロードします。")
  end

  it "keeps the root project upload guidance when no folder is selected" do
    sign_in_as(internal_user)

    get project_documents_path(project)

    expect(response).to have_http_status(:ok)
    panel = parsed_html.at_css(".manual-document-upload-panel")
    expect(panel).to be_present
    expect(panel["data-manual-document-upload-source-path-value"].to_s).to eq("")
    expect(panel.at_css(".manual-document-upload-panel__destination")).to be_nil
    expect(page_text).to include("ここにドロップすると案件直下の追加候補としてアップロードします。")
  end

  it "does not expose the manual upload panel to external users" do
    create(:project_membership, project:, user: external_user)
    sign_in_as(external_user)

    get project_documents_path(project, upload_source_path: "docs/internal")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".manual-document-upload-panel")).to be_nil
    expect(page_text).not_to include("ファイルをアップロード")
  end
end
