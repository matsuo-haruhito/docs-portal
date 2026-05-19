require "rails_helper"

RSpec.describe "Document upload review flow copy", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "UPLOADCOPY", name: "Upload Copy Project") }

  it "explains that document list drops create candidates reviewed on the diff screen" do
    sign_in_as(user)

    get project_documents_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書名・URL識別子・元パス・版・本文・キーワード・添付ファイル名/パス")
    expect(response.body).to include("案件直下の追加候補としてアップロードします")
    expect(response.body).to include("アップロード後に差分確認画面でOK/NGを選択します")
    expect(response.body).to include("複数ファイルはZIPにまとめるか、1ファイルずつアップロードしてください")
    expect(response.body).to include('role="status"')
    expect(response.body).to include('aria-live="polite"')
  end

  it "mentions the selected folder when dropping into a filtered source path" do
    sign_in_as(user)

    get project_documents_path(project, q: "docs/specs")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("docs/specs")
    expect(response.body).to include("直下の追加候補としてアップロードします")
    expect(response.body).to include('data-manual-document-upload-source-path-value="docs/specs"')
  end

  it "does not treat unsafe path-like queries as upload destinations" do
    sign_in_as(user)

    get project_documents_path(project, q: "../secret")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件直下の追加候補としてアップロードします")
    expect(response.body).not_to include('data-manual-document-upload-source-path-value="../secret"')
  end
end
