require "rails_helper"

RSpec.describe "Admin document set list search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:alpha_project) { create(:project, name: "Alpha Delivery Project", code: "alpha-delivery") }
  let(:beta_project) { create(:project, name: "Beta Rollout Project", code: "beta-rollout") }
  let(:gamma_project) { create(:project, name: "Gamma Design Project", code: "gamma-design") }

  let!(:alpha_delivery_set) do
    create(
      :document_set,
      project: alpha_project,
      name: "外部配布セット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end
  let!(:beta_internal_set) do
    create(
      :document_set,
      project: beta_project,
      name: "社内確認セット",
      set_type: :delivery,
      visibility_policy: :internal_only,
      sort_order: 2
    )
  end
  let!(:gamma_design_set) do
    create(
      :document_set,
      project: gamma_project,
      name: "設計レビューセット",
      set_type: :design,
      visibility_policy: :public_with_login,
      sort_order: 3
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def listed_document_set_names
    parsed_html.css('tbody td[data-rails-table-preferences-column-key="name"]').map do |node|
      node.text.squish
    end
  end

  def document_set_search_field
    parsed_html.at_css('form.document-set-filter-form input[name="q"]')
  end

  def clear_filter_targets
    parsed_html.css('a[href]').select { |node| node.text.squish == "条件をクリア" }.map { |node| node["href"] }
  end

  it "filters document sets by set name, project name, and project code" do
    sign_in_as(admin)

    get admin_document_sets_path, params: { q: "外部配布" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["外部配布セット"])
    expect(page_text).to include("検索: 外部配布")
    expect(document_set_search_field["value"]).to eq("外部配布")

    get admin_document_sets_path, params: { q: "Beta Rollout" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["社内確認セット"])
    expect(page_text).to include("検索: Beta Rollout")

    get admin_document_sets_path, params: { q: "gamma-design" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["設計レビューセット"])
    expect(page_text).to include("検索: gamma-design")
  end

  it "combines q with existing enum filters while ignoring invalid enum values" do
    sign_in_as(admin)

    get admin_document_sets_path, params: { q: "セット", set_type: "delivery", visibility_policy: "internal_only" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["社内確認セット"])
    expect(page_text).to include("検索: セット")
    expect(page_text).to include("種別: 送付用")
    expect(page_text).to include("公開範囲: 社内のみ")

    get admin_document_sets_path, params: { q: "Alpha", set_type: "unsupported" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["外部配布セット"])
    expect(page_text).to include("検索: Alpha")
    expect(page_text).not_to include("種別:")
  end

  it "shows the filtered empty state and clear link for unmatched q" do
    sign_in_as(admin)

    get admin_document_sets_path, params: { q: "no such document set", visibility_policy: "restricted_external" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 0件")
    expect(page_text).to include("検索: no such document set")
    expect(page_text).to include("公開範囲: 限定公開")
    expect(page_text).to include("条件に一致する文書セットはありません。")
    expect(clear_filter_targets).to include(admin_document_sets_path)
    expect(listed_document_set_names).to be_empty
  end
end
