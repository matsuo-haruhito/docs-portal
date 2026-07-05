require "rails_helper"

RSpec.describe "Admin company destructive cue", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def delete_confirm_messages
    parsed_html.css("form[data-turbo-confirm]").map { |form| form["data-turbo-confirm"] }
  end

  def delete_button_labels
    parsed_html.css("form[data-turbo-confirm] button").map { |button| button.text.squish }
  end

  def company_status_cells
    parsed_html.css("td[data-rails-table-preferences-column-key='status']").map { |cell| cell.text.squish }
  end

  it "distinguishes company delete from edit and active status labels" do
    active_company = create(:company, domain: "active.example.com", name: "Active Company", active: true)
    inactive_company = create(:company, domain: "inactive.example.com", name: "Inactive Company", active: false)

    sign_in_as(create(:user, :internal))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("編集")
    expect(delete_button_labels).to include("削除（影響確認）")
    expect(company_status_cells).to include("有効", "無効")
    expect(delete_confirm_messages).to include(
      "会社「#{active_company.display_name}」を完全に削除しますか？無効化ではありません。所属ユーザーや文書権限への影響を確認してください。",
      "会社「#{inactive_company.display_name}」を完全に削除しますか？無効化ではありません。所属ユーザーや文書権限への影響を確認してください。"
    )
  end

  it "does not show the destructive delete cue to company master admins" do
    company = create(:company, domain: "tenant.example.com", name: "Tenant")

    sign_in_as(create(:user, :external, :company_master_admin, company:))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Tenant")
    expect(page_text).not_to include("削除（影響確認）")
    expect(delete_confirm_messages).to be_empty
  end
end
