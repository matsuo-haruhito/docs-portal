require "rails_helper"

RSpec.describe "Admin file upload dry-run filter cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "keeps dry-run ID and metadata query boundary cues close to the filter controls" do
    sign_in_as(admin_user)

    get admin_file_upload_dry_runs_path

    expect(response).to have_http_status(:ok)

    filter_form = parsed_html.at_css("form.filters")
    dry_run_id_group = filter_form.css(".field").find { _1.at_css("input[name='dry_run_id']") }
    query_group = filter_form.css(".field").find { _1.at_css("input[name='q']") }

    aggregate_failures do
      expect(dry_run_id_group.text.squish).to include("dry-run の公開IDで完全一致検索します。")
      expect(dry_run_id_group.text.squish).to include("一部だけの ID では一致しないため、詳細画面などから ID 全体を貼り付けてください。")
      expect(query_group.text.squish).to include("検索対象: 同期元名、取り込み先パス (relative_path)、内容ハッシュ (content_hash)。")
      expect(query_group.text.squish).to include("長い値は特徴的な一部だけでも絞り込めます。")
      expect(query_group.text.squish).to include("クライアント source path は検索対象外")
    end
  end

  it "explains how to revise filtered zero-result dry-run searches" do
    sign_in_as(admin_user)

    get admin_file_upload_dry_runs_path, params: { dry_run_id: "idry-partial", q: "too-long-source-path-fragment" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する単体ファイルアップロード確認履歴はありません。")
    expect(page_text).to include("dry-run ID、同期元名・取り込み先パス・内容ハッシュ、案件、状態の条件を見直すか、絞り込み解除で一覧に戻してください。")
    expect(page_text).to include("dry-run ID は完全一致です。検索語は同期元名・取り込み先パス・内容ハッシュの特徴的な一部で見直してください。")
  end
end
