require "rails_helper"

RSpec.describe "Admin access log AI context filter guidance", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def guidance_group
    parsed_html.at_css('[data-testid="ai-context-filter-guidance"]')
  end

  it "groups AI context mode and scope as target-type-specific conditions" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(guidance_group).to be_present
    expect(guidance_group["role"]).to eq("group")
    expect(guidance_group["aria-labelledby"]).to eq("ai-context-filter-guidance-title")
    expect(guidance_group.at_css("#ai-context-filter-guidance-title").text.squish).to eq("AI context export 用の追加条件")
    expect(guidance_group.text.squish).to include("対象種別で AI context export を選んだ場合だけ、AI出力モード・範囲が有効です。")
    expect(guidance_group.text.squish).to include("AI出力モード・範囲は page / file / zip / webhook など他の対象種別では条件から外れます。")
    expect(guidance_group.css('select[name="ai_context_mode"]').size).to eq(1)
    expect(guidance_group.css('select[name="ai_context_scope"]').size).to eq(1)
  end
end
