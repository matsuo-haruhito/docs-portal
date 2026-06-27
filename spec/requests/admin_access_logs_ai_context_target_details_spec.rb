require "rails_helper"

RSpec.describe "Admin access log AI context target details", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_ai_context_log!(target_name:)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      action_type: :download,
      target_type: "ai_context",
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at: Time.current
    )
  end

  it "renders AI context target badges including scoped count without hiding the safe raw preview" do
    target_name = "mode=compact;scope=selected;selected_count=4;scoped_count=2;exported_count=1"
    create_ai_context_log!(target_name:)

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("AI出力モード: コンパクト")
    expect(page_text).to include("AI出力範囲: 選択")
    expect(page_text).to include("選択数: 4件")
    expect(page_text).to include("案件内候補: 2件")
    expect(page_text).to include("出力数: 1件")
    expect(page_text).to include("監査用 target_name preview")
    expect(page_text).to include(target_name)
  end

  it "keeps malformed AI context target previews safe instead of rendering sensitive badges" do
    create_ai_context_log!(
      target_name: "mode=full;scope=selected;selected_count=2;scoped_count=2;exported_count=2;Authorization: Basic raw-basic;api_key: raw-key;path=/home/alice/private.pdf?token=raw-token"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("監査用 target_name preview")
    expect(page_text).not_to include("AI出力モード: 詳細")
    expect(page_text).not_to include("raw-basic")
    expect(page_text).not_to include("raw-key")
    expect(page_text).not_to include("raw-token")
    expect(page_text).not_to include("/home/alice")
    expect(page_text).to include("Authorization: [FILTERED]")
    expect(page_text).to include("api_key:[FILTERED]")
    expect(page_text).to include("[path hidden]")
  end
end
