require "rails_helper"

RSpec.describe "Admin access log AI context filter guidance", type: :request do
  let(:admin_company) { create(:company, domain: "audit-guidance.example.com", name: "Audit Guidance Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def log_target_names
    parsed_html.css("table tbody tr").filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
  end

  def create_access_log!(target_type:, target_name:)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      action_type: :download,
      target_type:,
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at: Time.current
    )
  end

  it "marks AI output mode and scope filters active when target type is AI context export" do
    create_access_log!(
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      target_type: "ai_context",
      target_name: "mode=full;scope=all;selected_count=0;exported_count=9"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=compact;scope=selected;selected_count=2;exported_count=2"])
    expect(page_text).to include("対象種別: AI context export AI出力モード・範囲は今回の検索条件として有効です。")
    expect(page_text).to include("AI出力モード: コンパクト")
    expect(page_text).not_to include("AI出力モード: compact")
    expect(page_text).to include("AI出力範囲: 選択")
    expect(page_text).to include("CSV条件metadata JSON")
  end

  it "explains AI output filters are excluded when another target type is selected" do
    create_access_log!(
      target_type: "zip",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "zip", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=compact;scope=selected;selected_count=2;exported_count=2"])
    expect(page_text).to include("対象外 対象種別が AI context export ではないため、AI出力モード・範囲は今回の有効な条件から外れます。")
    expect(page_text).not_to include("AI出力モード: コンパクト")
    expect(page_text).not_to include("AI出力モード: compact")
    expect(page_text).not_to include("AI出力範囲: 選択")
  end
end