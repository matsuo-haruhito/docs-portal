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

  it "shows every catalog entry in diagnostics with a model browser link" do
    total_count = Admin::ModelBrowserCatalog.entries.size

    sign_in_as(admin_user)

    get admin_diagnostics_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css(".model-browser-card-metrics").size).to eq(total_count)
    expect(parsed_html.at_css("a[href='#{admin_model_browser_path}']")).to be_present
  end
end
