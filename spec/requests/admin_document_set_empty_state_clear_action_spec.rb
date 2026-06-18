require "rails_helper"

RSpec.describe "Admin document set filtered empty state clear action", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def table_preference_surfaces
    parsed_html.css(%([data-rails-table-preferences-table-key-value="admin_document_sets"]))
  end

  it "shows a button-style clear action in the filtered empty state without rendering table preferences" do
    create(:document_set, project:, name: "配送限定セット", set_type: :delivery, visibility_policy: :restricted_external)
    create(:document_set, project:, name: "配送社内セット", set_type: :delivery, visibility_policy: :internal_only)
    create(:document_set, project:, name: "設計公開セット", set_type: :design, visibility_policy: :public_with_login)

    sign_in_as(admin)

    get admin_document_sets_path, params: { set_type: "delivery", visibility_policy: "public_with_login" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 0件")
    expect(page_text).to include("条件に一致する文書セットはありません。")

    form_clear_actions = parsed_html.css("form.document-set-filter-form .form-actions a.button.secondary[href='#{admin_document_sets_path}']").select do |node|
      node.text.squish == "条件をクリア"
    end
    expect(form_clear_actions.size).to eq(1)

    empty_state = parsed_html.at_css(".document-set-filter-empty-state")
    expect(empty_state).to be_present
    empty_state_clear_action = empty_state.at_css(".form-actions a.button.secondary[href='#{admin_document_sets_path}']")
    expect(empty_state_clear_action&.text&.squish).to eq("条件をクリア")

    expect(table_preference_surfaces).to be_empty
  end
end
