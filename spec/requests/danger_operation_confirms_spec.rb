require "rails_helper"

RSpec.describe "Danger operation confirms", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, name: "Confirm Project") }
  let!(:document) { create(:document, project:, title: "Confirm Document", slug: "confirm-doc") }
  let!(:document_set) { create(:document_set, project:, name: "Confirm Set") }

  it "shows concrete delete confirmations on admin index pages" do
    sign_in_as(admin_user)

    get admin_documents_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書「Confirm Document」を削除しますか？")

    get admin_document_sets_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書セット「Confirm Set」を削除しますか？")
  end

  it "shows impact counts before applying the standard template" do
    sign_in_as(admin_user)

    get edit_admin_project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("標準テンプレートを適用しますか？")
    expect(response.body).to include("作成予定")
    expect(response.body).to include("スキップ予定")
  end
end
