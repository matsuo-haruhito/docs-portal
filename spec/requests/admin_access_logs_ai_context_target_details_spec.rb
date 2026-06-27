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

  def log_target_names
    parsed_html.css("table tbody tr").filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
  end

  def ai_context_guidance
    parsed_html.at_css('[data-testid="ai-context-filter-guidance"]')
  end

  def ai_context_mode_filter
    parsed_html.at_css('[data-testid="ai-context-mode-filter"]')
  end

  def ai_context_scope_filter
    parsed_html.at_css('[data-testid="ai-context-scope-filter"]')
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

  it "marks AI context filters as inactive without changing submitted non-AI target params" do
    create_access_log!(
      target_type: "zip",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_ai_context_log!(
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "zip", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=compact;scope=selected;selected_count=2;exported_count=2"])
    expect(ai_context_guidance.text.squish).to include("対象外")
    expect(ai_context_guidance.text.squish).to include("AI出力モード・範囲は今回の有効な条件から外れます")

    [ai_context_mode_filter, ai_context_scope_filter].each do |filter|
      expect(filter["aria-disabled"]).to eq("true")
      expect(filter["aria-describedby"].split).to contain_exactly("ai-context-filter-state", "ai-context-filter-usage-note")
      expect(filter["disabled"]).to be_nil
    end

    expect(parsed_html.at_css('select[name="ai_context_mode"] option[value="compact"][selected]')).to be_nil
    expect(parsed_html.at_css('select[name="ai_context_scope"] option[value="selected"][selected]')).to be_nil
    expect(page_text).not_to include("AI出力モード:")
    expect(page_text).not_to include("AI出力範囲:")
  end

  it "marks AI context filters as active when AI context export is selected" do
    create_ai_context_log!(
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(ai_context_guidance.text.squish).to include("対象種別: AI context export")
    expect(ai_context_guidance.text.squish).to include("AI出力モード・範囲は今回の検索条件として有効です")
    expect(ai_context_mode_filter["aria-disabled"]).to eq("false")
    expect(ai_context_scope_filter["aria-disabled"]).to eq("false")
    expect(parsed_html.at_css('select[name="ai_context_mode"] option[value="compact"][selected]').text).to eq("コンパクト")
    expect(parsed_html.at_css('select[name="ai_context_scope"] option[value="selected"][selected]').text).to eq("選択")
  end
end
