require "rails_helper"

RSpec.describe "Admin model browser design cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows the model browser query limit at the index search input" do
    sign_in_as(admin_user)

    get admin_model_browser_path

    expect(response).to have_http_status(:ok)

    search_input = parsed_html.at_css("input[name='q']")

    expect(search_input).to be_present
    expect(search_input["maxlength"]).to eq(Admin::ModelBrowsersController::MODEL_BROWSER_QUERY_MAX_LENGTH.to_s)
    expect(response.body).to include("検索語は最大#{Admin::ModelBrowsersController::MODEL_BROWSER_QUERY_MAX_LENGTH}文字です。")
  end

  it "explains that the dashboard model observation is an excerpt with a full catalog link" do
    total_count = Admin::ModelBrowserCatalog.entries.size

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("主要 model 8件を抜粋")
    expect(response.body).to include("catalog 全体 #{total_count}件")

    model_browser_link = parsed_html.css("a[href='#{admin_model_browser_path}']").find do |link|
      link.text.squish.include?("全#{total_count}件")
    end

    expect(model_browser_link).to be_present
    expect(model_browser_link.text.squish).to eq("モデルブラウザを開く（全#{total_count}件）")
  end
end
