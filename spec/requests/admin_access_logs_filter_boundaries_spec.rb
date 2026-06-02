require "rails_helper"

RSpec.describe "Admin access log filter boundaries", type: :request do
  let(:admin_company) { create(:company, domain: "filter-admin.example.com", name: "Filter Admin Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "BOUNDARY", name: "Boundary Project") }
  let(:document) { create(:document, project:, title: "Boundary Document", slug: "boundary-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def log_rows
    parsed_html.css("table tbody tr")
  end

  def log_target_names
    log_rows.filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
  end

  def selected_option_value(name)
    parsed_html.at_css(%(select[name="#{name}"] option[selected]))&.[]("value")
  end

  def create_access_log!(target_name:, action_type: :view, target_type: "page", accessed_at: Time.current, user: admin_user, company: admin_company, project: self.project, document: self.document, document_version: version)
    AccessLog.create!(
      user:,
      company:,
      project:,
      document:,
      document_version:,
      action_type:,
      target_type:,
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  it "keeps invalid accessed date filters visible without constraining results" do
    create_access_log!(target_name: "kept-by-invalid-date.html")

    sign_in_as(admin_user)

    get admin_access_logs_path(from: "not-a-date", to: "2026-99-99")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["kept-by-invalid-date.html"])
    expect(page_text).to include("表示中: 1件 / 最新200件までを表示 / 絞り込み中")
    expect(page_text).to include("開始日: 日付を確認")
    expect(page_text).to include("終了日: 日付を確認")
    expect(page_text).to include("期間指定後も、条件に一致する監査ログを新しい順に最新200件まで表示します。")
  end

  it "handles missing project, company, and user ids as empty filters instead of failing" do
    create_access_log!(target_name: "existing-log.html")

    sign_in_as(admin_user)

    get admin_access_logs_path(project_id: "999901", company_id: "999902", user_id: "999903")

    expect(response).to have_http_status(:ok)
    expect(log_rows).to be_empty
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(page_text).to include("案件: 指定あり")
    expect(page_text).to include("会社: 指定あり")
    expect(page_text).to include("ユーザー: 指定あり")
  end

  it "does not leak AI context mode or scope filters into non AI-context target types" do
    create_access_log!(
      action_type: :download,
      target_type: "zip",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "zip", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=compact;scope=selected;selected_count=2;exported_count=2"])
    expect(selected_option_value("target_type")).to eq("zip")
    expect(selected_option_value("ai_context_mode")).to be_nil
    expect(selected_option_value("ai_context_scope")).to be_nil
    expect(page_text).not_to include("AI context mode:")
    expect(page_text).not_to include("AI context scope:")
  end
end
