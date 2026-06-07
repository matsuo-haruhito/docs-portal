require "rails_helper"
require "uri"

RSpec.describe "Admin access log AI context filter guidance", type: :request do
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

  def csv_export_link_params
    link = parsed_html.css("a[href]").find { _1.text.squish.include?("CSV export") }

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
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

  it "explains that AI context mode and scope only apply to AI context exports" do
    create_access_log!(target_type: "page", target_name: "project-page.html")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("AI context export 用の追加条件")
    expect(page_text).to include("対象種別で AI context export を選んだ場合だけ、下の mode / scope が有効になります。")
    expect(page_text).to include("AI出力モード・範囲は page / file / zip / webhook など他の対象種別では条件から外れ")
    expect(page_text).to include("CSV export や有効な条件にも残りません。")
  end

  it "keeps AI context mode and scope out of active conditions for non AI targets" do
    create_access_log!(target_type: "zip", target_name: "mode=compact;scope=selected;archive.zip")
    create_access_log!(target_type: "ai_context", target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2")

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "zip", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("対象種別: ZIP")
    expect(page_text).not_to include("AI context mode: compact")
    expect(page_text).not_to include("AI context scope: 選択")
    expect(parsed_html.at_css('select[name="ai_context_mode"] option[value="compact"][selected]')).to be_nil
    expect(parsed_html.at_css('select[name="ai_context_scope"] option[value="selected"][selected]')).to be_nil
    expect(csv_export_link_params).to include("target_type" => "zip")
    expect(csv_export_link_params.keys).not_to include("ai_context_mode", "ai_context_scope")
  end
end
