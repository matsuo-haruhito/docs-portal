require "rails_helper"

RSpec.describe "Admin company master filters", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def result_table_text
    parsed_html.css("tbody").text.squish
  end

  def keyword_input
    parsed_html.at_css('input[name="q"]')
  end

  def input_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def selected_option_value(name)
    parsed_html.at_css(%(select[name="#{name}"] option[selected]))&.[]("value")
  end

  def link_href(text)
    parsed_html.css("a").find { |link| link.text.squish == text }&.[]("href")
  end

  def form_link_texts(action_path)
    parsed_html.css(%(form[action="#{action_path}"] a)).map { |link| link.text.squish }
  end

  let!(:company) { create(:company, domain: "alpha.example.com", name: "Alpha Company", active: true) }
  let!(:other_company) { create(:company, domain: "omega.example.com", name: "Omega Holdings", active: true) }
  let!(:inactive_company) { create(:company, domain: "dormant.example.com", name: "Dormant Partner", active: false) }

  it "hides the form clear action until company filters are active" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("会社を探す")
    expect(keyword_input).to be_present
    expect(keyword_input["placeholder"]).to eq("ドメイン・会社名")
    expect(keyword_input["maxlength"]).to eq("100")
    expect(page_text).to include("ドメイン・会社名の断片で検索できます。最大100文字。")
    expect(response.body).not_to include("ドメイン・会社名・表示名")
    expect(form_link_texts(admin_companies_path)).not_to include("条件をクリア")

    get admin_companies_path, params: { active: "true" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("適用中: 状態: 有効")
    expect(form_link_texts(admin_companies_path)).to include("条件をクリア")
    expect(link_href("条件をクリア")).to eq(admin_companies_path)
  end

  it "filters companies by keyword while preserving table preferences" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path, params: { q: "OMEGA" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("会社を探す")
    expect(page_text).to include("Omega Holdings")
    expect(page_text).not_to include("Alpha Company")
    expect(page_text).not_to include("Dormant Partner")
    expect(input_value("q")).to eq("OMEGA")
    expect(page_text).to include("会社一覧の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="domain"')
  end

  it "filters companies by active state and ignores unsupported state values" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path, params: { active: "false" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Dormant Partner")
    expect(page_text).not_to include("Alpha Company")
    expect(page_text).not_to include("Omega Holdings")
    expect(selected_option_value("active")).to eq("false")

    get admin_companies_path, params: { q: "alpha", active: "unsupported" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Alpha Company")
    expect(page_text).not_to include("Omega Holdings")
    expect(selected_option_value("active")).to be_nil
  end

  it "shows a filtered empty state separately from the unregistered empty state" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path, params: { q: "missing-company" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する会社はありません。")
    expect(page_text).to include("キーワードや状態の条件を変更するか、条件をクリアしてください。")
    expect(parsed_html.css('section.card a[href="/admin/companies"]').map(&:text).join).to include("条件をクリア")
    expect(page_text).not_to include("まだ会社は登録されていません。")
    expect(input_value("q")).to eq("missing-company")
  end

  it "keeps company_master_admin searches inside the current company scope" do
    manager = create(:user, :external, :company_master_admin, company:)
    sign_in_as(manager)

    get admin_companies_path, params: { q: "omega" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する会社はありません。")
    expect(page_text).not_to include("Omega Holdings")
    expect(page_text).not_to include("Dormant Partner")

    get admin_companies_path, params: { q: "alpha", active: "true" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Alpha Company")
    expect(page_text).not_to include("Omega Holdings")
    expect(page_text).not_to include("Dormant Partner")
    expect(input_value("q")).to eq("alpha")
    expect(selected_option_value("active")).to eq("true")
  end

  it "paginates filtered companies while preserving filters in page links" do
    matching_companies = Array.new(3) do |index|
      create(:company, domain: "tenant-#{index}.example.com", name: "Tenant Page #{index}", active: true)
    end
    create(:company, domain: "tenant-inactive.example.com", name: "Tenant Page Inactive", active: false)

    sign_in_as(create(:user, :internal))

    get admin_companies_path, params: { q: "tenant page", active: "true", per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 3件")
    expect(page_text).to include("表示中: 1-2件 / 3件")
    expect(result_table_text).to include(matching_companies.first.domain)
    expect(result_table_text).to include(matching_companies.second.domain)
    expect(result_table_text).not_to include(matching_companies.third.domain)
    expect(link_href("次へ")).to include("q=tenant+page", "active=true", "per_page=2", "page=2")

    get admin_companies_path, params: { q: "tenant page", active: "true", per_page: 2, page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 3-3件 / 3件")
    expect(result_table_text).to include(matching_companies.third.domain)
    expect(result_table_text).not_to include(matching_companies.first.domain)

    get admin_companies_path, params: { q: "tenant page", active: "true", per_page: 2, page: 99 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 3-3件 / 3件")
    expect(result_table_text).to include(matching_companies.third.domain)
  end
end
