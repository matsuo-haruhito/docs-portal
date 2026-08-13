require "rails_helper"

RSpec.describe "Admin access log filter form", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows query targets and length cues for free-text access log filters" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)

    max_length = Admin::AccessLogsController::ACCESS_LOG_QUERY_MAX_LENGTH.to_s
    target_query_input = parsed_html.at_css(%(input[name="q"]))
    document_query_input = parsed_html.at_css(%(input[name="document_q"]))

    expect(target_query_input["maxlength"]).to eq(max_length)
    expect(document_query_input["maxlength"]).to eq(max_length)

    advanced_filters = parsed_html.at_css("form details.filter-details")
    expect(advanced_filters).to be_present
    expect(advanced_filters["open"]).to be_nil
    expect(advanced_filters.at_css(%(input[name="q"]))).to be_present
    expect(advanced_filters.at_css(%(input[name="document_q"]))).to be_present
    expect(advanced_filters.at_css(%(select[name="company_id"]))).to be_present
    expect(advanced_filters.at_css(%(select[name="user_id"]))).to be_present
    expect(parsed_html.at_css(%(.admin-filter-toolbar__fields select[name="action_type"]))).to be_present
    expect(parsed_html.at_css(%(.admin-filter-toolbar__fields select[name="target_type"]))).to be_present
    expect(parsed_html.at_css(%(.admin-filter-toolbar__fields select[name="project_id"]))).to be_present
    expect(page_text).to include("対象名やIPアドレスの断片で検索できます。最大100文字。")
    expect(page_text).to include("文書名やURL識別子の断片で検索できます。最大100文字。")
    expect(page_text).to include("最新200件")
    expect(page_text).to include("AI出力モード・範囲は page / file / zip / webhook など他の対象種別では条件から外れ")

    get admin_access_logs_path(q: "target")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css("form details.filter-details")["open"]).not_to be_nil
  end
end
