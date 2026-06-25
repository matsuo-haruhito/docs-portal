require "rails_helper"

RSpec.describe "Admin access log AI context target display", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def target_cells
    parsed_html.css('td[data-rails-table-preferences-column-key="target"]')
  end

  def create_access_log!(target_type:, target_name:)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      project:,
      document:,
      document_version: version,
      action_type: :download,
      target_type:,
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at: Time.current
    )
  end

  it "keeps structured AI context target values readable without badge raw titles" do
    create_access_log!(
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("AI context export")
    expect(page_text).to include("AI出力モード: 詳細")
    expect(page_text).to include("AI出力範囲: 選択")
    expect(page_text).to include("選択数: 2件")
    expect(page_text).to include("出力数: 2件")
    expect(page_text).to include("監査用 target_name preview")
    expect(page_text).not_to include("mode: full")
    expect(page_text).not_to include("scope: 選択")
    expect(target_cells.first.css("span.badge[title]")).to be_empty
    expect(target_cells.first.at_css("details code").text).to eq("mode=full;scope=selected;selected_count=2;exported_count=2")
  end

  it "masks sensitive AI context target fragments in the rendered HTML" do
    create_access_log!(
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2;token=raw-token-123;Authorization: Bearer raw-bearer-456;source=C:/Users/alice/private/report.md"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("raw-token-123")
    expect(response.body).not_to include("raw-bearer-456")
    expect(response.body).not_to include("C:/Users/alice/private/report.md")
    expect(page_text).to include("token=[FILTERED]")
    expect(page_text).to include("Authorization: [FILTERED]")
    expect(page_text).to include("source=[path hidden]")
    expect(target_cells.first.css("span.badge[title]")).to be_empty
  end

  it "uses safe preview for unparsable AI context targets without changing normal target names" do
    create_access_log!(target_type: "zip", target_name: "audit.zip")
    create_access_log!(
      target_type: "ai_context",
      target_name: "authorization=Bearer raw-fallback-token;secret=raw-secret-value;/home/alice/private.txt"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("raw-fallback-token")
    expect(response.body).not_to include("raw-secret-value")
    expect(response.body).not_to include("/home/alice/private.txt")
    expect(page_text).to include("authorization=[FILTERED]")
    expect(page_text).to include("secret=[FILTERED]")
    expect(page_text).to include("[path hidden]")
    expect(page_text).to include("audit.zip")
  end
end
