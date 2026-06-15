require "rails_helper"
require "fileutils"

RSpec.describe "Admin API specification build history empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:build_history_marker_path) { Rails.root.join("tmp", "api_specification_build.history.json") }

  before do
    @original_build_history_marker = build_history_marker_path.exist? ? build_history_marker_path.read : nil
    FileUtils.rm_f(build_history_marker_path)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)
  end

  after do
    if @original_build_history_marker
      FileUtils.mkdir_p(build_history_marker_path.dirname)
      File.write(build_history_marker_path, @original_build_history_marker)
    else
      FileUtils.rm_f(build_history_marker_path)
    end
  end

  it "explains that an empty build history is not a success signal" do
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("直近build履歴")
    expect(response.body).to include("直近build履歴はまだ記録されていません")
    expect(response.body).to include("これは build 成功、失敗なし、CI green を意味しません")
    expect(response.body).to include("表示状態、Build manifest、主要ページとsource を確認")
    expect(response.body).not_to include("API仕様ページ専用 build の直近結果だけを read-only に表示します")
  end
end
