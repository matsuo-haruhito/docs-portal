require "rails_helper"

RSpec.describe "Admin generated file run query cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  it "shows the query maxlength and short-fragment guidance without changing existing filters" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)

    query_input = parsed_html.at_css('input[name="q"]')
    expect(query_input).to be_present
    expect(query_input["maxlength"]).to eq(Admin::GeneratedFileRunsController::QUERY_MAX_LENGTH.to_s)
    expect(query_input["placeholder"]).to eq("gfr... / docs/source.yml / timeout / metadata断片")

    expect(page_text).to include("検索語は最大#{Admin::GeneratedFileRunsController::QUERY_MAX_LENGTH}文字です。")
    expect(page_text).to include("入力パス・変更ファイル・生成パス・エラー文・補助メタデータを検索します。")
    expect(page_text).to include("長いメタデータJSONやエラー文は、特徴的な短い断片で探してください。")

    %w[status job_id generator output_writer event_source created_from created_to].each do |field_name|
      expect(parsed_html.at_css(%([name="#{field_name}"]))).to be_present
    end
  end
end
