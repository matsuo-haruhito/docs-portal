require "rails_helper"

RSpec.describe "admin external folder sync source warning detail cue", type: :model do
  let(:source) { Rails.root.join("app/views/admin/external_folder_sync_sources/show.html.slim").read }

  it "links warning approval guidance to the latest run result details" do
    expect(source).to include("latest_run_detail_anchor = latest_run&.public_id ?")
    expect(source).to include("直近プレビューの結果詳細へ移動")
    expect(source).to include('tr id="#{run.public_id}-result-details"')
    expect(source).to include("承認対象の直近プレビュー")
  end

  it "keeps force apply behavior in the existing warning approval branch" do
    warning_branch = source[/external_folder_sync_force_apply_visible\?\(latest_run\).*?latest_run\.blank\?/m]

    expect(warning_branch).to include("警告を承認して同期する")
    expect(warning_branch).to include("同期プレビューを再実行")
    expect(warning_branch).to include("data: { turbo_method: :post")
    expect(warning_branch).to include("結果詳細を確認済みの場合のみ実行してください")
  end
end
