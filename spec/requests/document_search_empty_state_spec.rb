require "rails_helper"

RSpec.describe "Document search empty state", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "EMPTYSEARCH", name: "Empty Search Project") }

  it "shows guidance and hides zip export controls when no documents match" do
    create(:document, project:, title: "通常資料", slug: "normal-doc")

    sign_in_as(user)

    get project_documents_path(project, q: "no-match-keyword")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する文書はありません")
    expect(response.body).to include("no-match-keyword")
    expect(response.body).to include("条件をクリア")
    expect(response.body).not_to include("ZIP出力オプション")
  end
end
