require "rails_helper"

RSpec.describe "Admin document usage reports", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def clear_link
    parsed_html.css("a[href='#{admin_document_usage_reports_path}']").find do |link|
      link.text.include?("条件をクリア")
    end
  end

  it "shows selection controls and a prompt when no project is selected" do
    project
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書利用状況")
    expect(page_text).to include("案件を選択すると集計結果を表示します。")

    form = parsed_html.at_css("form[action='#{admin_document_usage_reports_path}']")
    expect(form).to be_present
    expect(form.at_css("select[name='project_id']")).to be_present

    option_texts = form.css("option").map { |option| option.text.squish }
    expect(option_texts).to include("選択してください")
    expect(option_texts.any? { |text| text.include?("Usage Project") }).to be(true)

    expect(clear_link).to be_present
    expect(clear_link.text).to include("条件をクリア")
  end

  it "shows usage summary, selected project state, and document links for the selected project" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 11, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Usage Project")
    expect(page_text).to include("USAGE")
    expect(page_text).to include("Manual")
    expect(page_text).to include("閲覧: 1")
    expect(page_text).to include("ダウンロード: 1")
    expect(page_text).to include("既読確認: 1")

    selected_option = parsed_html.at_css("select[name='project_id'] option[selected]")
    expect(selected_option).to be_present
    expect(selected_option["value"]).to eq(project.id.to_s)
    expect(selected_option.text.squish).to include("Usage Project")

    headers = parsed_html.css("table thead th").map { |header| header.text.squish }
    expect(headers).to include("文書名", "カテゴリ", "種別", "公開範囲", "利用", "閲覧", "ダウンロード", "既読確認", "最終アクセス")

    document_link = parsed_html.at_css("a[href='#{project_document_path(project, document.slug)}']")
    expect(document_link).to be_present
    expect(document_link.text).to eq("Manual")

    expect(clear_link).to be_present
    expect(clear_link.text).to include("条件をクリア")
  end

  it "forbids external users and company master admins" do
    sign_in_as(external_user)
    get admin_document_usage_reports_path
    expect(response).to have_http_status(:forbidden)

    sign_in_as(company_master_admin)
    get admin_document_usage_reports_path
    expect(response).to have_http_status(:forbidden)
  end
end
