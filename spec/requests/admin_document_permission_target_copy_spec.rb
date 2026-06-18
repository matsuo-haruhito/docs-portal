require "rails_helper"

RSpec.describe "Admin document permission target copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "explains that only the chosen target side should remain filled" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("保存時は、選んだ側だけを残し、もう一方は空にします。")
    expect(page_text).to include("会社全体に同じ権限を付与する場合だけ選択します。ユーザー個別へ付与する場合、この欄は空にします。")
    expect(page_text).to include("特定の1名にだけ権限を付与する場合だけ選択します。会社全体へ付与する場合、この欄は空にします。")
  end

  it "shows a section-level correction cue when both target sides are submitted" do
    document = create(:document, title: "Permission Target")
    company = create(:company, name: "Customer Company")
    external_user = create(:user, :external, email_address: "external@example.com")

    sign_in_as(admin_user)

    post admin_document_permissions_path, params: {
      document_permission: {
        document_id: document.id,
        company_id: company.id,
        user_id: external_user.id,
        access_level: "view"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("適用対象の選択を確認してください。")
    expect(page_text).to include("会社またはユーザーのどちらか一方だけを残してください。")
    expect(page_text).to include("適用対象は会社かユーザーのどちらか一方だけを指定してください。")
  end
end
