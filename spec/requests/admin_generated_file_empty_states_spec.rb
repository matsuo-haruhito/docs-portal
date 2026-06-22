require "rails_helper"

RSpec.describe "Admin generated file empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows an initial empty state for generated file runs with no rows" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("生成ファイル実行履歴はまだありません。")
    expect(response.body).not_to include("条件に一致する生成ファイル実行履歴はありません。")
    expect(response.body).not_to include("すべての生成ファイル実行履歴を見る")
    expect(parsed_html.at_css(".generated-file-run-filter-empty-state")).to be_nil
  end

  it "shows a filtered empty state action for generated file runs with no matching rows" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する生成ファイル実行履歴はありません。")
    expect(response.body).to include("これは表示フィルタの結果です。")
    expect(response.body).to include("条件を見直すか、すべての生成ファイル実行履歴を表示してください。")

    empty_state = parsed_html.at_css(".generated-file-run-filter-empty-state")
    expect(empty_state).to be_present
    clear_action = empty_state.at_css(%(p.actions a.rounded.border[href="#{admin_generated_file_runs_path}"]))
    expect(clear_action&.text&.squish).to eq("すべての生成ファイル実行履歴を見る")
  end

  it "shows an initial empty state for generated file events with no rows" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("生成ファイルイベントはまだありません。")
    expect(response.body).not_to include("検索条件に一致する生成ファイルイベントはありません。")
    expect(parsed_html.at_css(".generated-file-event-filter-empty-state")).to be_nil
  end

  it "shows a filtered empty state action for generated file events with no matching rows" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件に一致する生成ファイルイベントはありません。")
    expect(response.body).to include("これは表示フィルタの結果です。")

    retry_panel = parsed_html.at_css("div.rounded.border.border-red-100")
    expect(retry_panel).to be_present
    retry_text = retry_panel.text.squish
    expect(retry_text).to include("失敗分を一括再投入")
    expect(retry_text).to include("再投入は表示フィルタではなく")
    expect(retry_text).to include("現在の条件で再投入対象")
    expect(retry_text).to include("一括再投入は古い失敗分から最大100件です。")
    expect(retry_text).to include("対象がないため一括再投入できません。")
    expect(retry_text).not_to include("再dispatch")

    empty_state = parsed_html.at_css(".generated-file-event-filter-empty-state")
    expect(empty_state).to be_present
    expect(empty_state.text.squish).to include("一括再投入対象の有無とは別に")
    expect(empty_state.text.squish).not_to include("再dispatch")
    clear_action = empty_state.at_css(%(p.actions a.rounded.border[href="#{admin_generated_file_events_path}"]))
    expect(clear_action&.text&.squish).to eq("すべての生成ファイルイベントを見る")
  end
end
