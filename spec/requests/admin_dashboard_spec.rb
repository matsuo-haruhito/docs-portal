require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:version) { create(:document_version) }

  it "shows document file health summary to internal admins" do
    DocumentFile.create!(
      document_version: version,
      file_name: "missing.txt",
      content_type: "text/plain",
      storage_key: "spec/admin-dashboard/missing.txt",
      file_size: 0
    )

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ドキュメントファイル健全性")
    expect(response.body).to include("モデルブラウザ")
    expect(response.body).to include("missing.txt")
    expect(response.body).to include("spec/admin-dashboard/missing.txt")
  end
end
