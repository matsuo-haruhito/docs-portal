require "rails_helper"

RSpec.describe "Admin read confirmations initial state", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:viewer) { create(:user, :external, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "explains that project selection comes before read confirmation detail filters" do
    create(:read_confirmation, document:, user: viewer)
    sign_in_as(admin_user)

    get admin_read_confirmations_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択してください")
    expect(page_text).to include("案件を選択すると既読確認の内訳を表示します。")
    expect(page_text).to include("文書名またはURL識別子、期間、会社、確認者は、案件を選択した後に既読確認の明細を絞り込む条件です。")
    expect(page_text).to include("CSV出力と表示設定は、案件選択後の内訳表示で利用できます。")
    expect(page_text).not_to include("Manual")
    expect(page_text).not_to include("Reader One / reader@example.com")
    expect(parsed_html.at_css("select[name='project_id']")).to be_present
    expect(parsed_html.css("table tbody tr")).to be_empty
  end
end
