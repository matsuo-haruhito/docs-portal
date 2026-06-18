require "rails_helper"

RSpec.describe "Admin bulk edit candidate cues", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Alpha Project") }
  let!(:document) { create(:document, project:, title: "Target Doc", category: :spec, visibility_policy: :restricted_external) }

  before do
    version = create(:document_version, document:, snapshot_kind: "current")
    document.update!(latest_version: version)
  end

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "explains that document master candidates are only the initial checked set" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      candidate_document_ids: [document.id],
      source_filter_summaries: ["キーワード: Alpha Project"]
    }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("文書マスタ一覧から引き継いだ初期候補: 1件")
      expect(page_text).to include("文書マスタの検索結果から最初に選択された候補です")
      expect(page_text).to include("dry-run 作成対象は、この画面で最後にチェックが付いている文書です")
      expect(page_text).to include("画面内検索と選択済みだけ表示は表示補助です")
      expect(page_text).to include("作成対象はチェック状態で決まります")
      expect(page_text).to include("代表条件: キーワード: Alpha Project")
      expect(page_text).to include("Target Doc")
    end
  end

  it "keeps the document master recovery cue when no valid candidates remain" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      candidate_document_ids: ["missing"]
    }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("文書マスタ一覧から引き継いだ初期候補: 0件")
      expect(page_text).to include("文書マスタの検索結果から最初に選択された候補です")
      expect(page_text).to include("有効な候補文書がありません。文書マスタで条件を見直してから一括編集候補を開いてください。")
      expect(page_text).to include("0件選択中")
      expect(page_text).to include("0件表示中")
    end
  end

  it "does not show document master candidate copy on the normal new screen" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).not_to include("文書マスタ一覧から引き継いだ初期候補")
      expect(page_text).not_to include("文書マスタの検索結果から最初に選択された候補です")
      expect(page_text).to include("画面内検索と選択済みだけ表示は表示補助です")
    end
  end
end
