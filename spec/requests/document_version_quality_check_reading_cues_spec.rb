require "rails_helper"

RSpec.describe "Document version quality check reading cues", type: :request do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published, search_body_text: "internal_only") }
  let(:internal_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  before do
    document.update!(latest_version: version)
    sign_in_as(internal_user)
  end

  it "explains severity and read-only export roles on the html page" do
    get document_version_quality_check_path(version)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("fail は error がある状態です。warning は確認が必要な注意、info は参考情報として扱ってください。")
    expect(page_text).to include("JSON / Markdown は handoff や evidence 用の read-only export です。この画面から品質チェック結果は変更されません。")
    expect(parsed_html.css("a[href]").map { _1.text.squish }).to include("JSON", "Markdown")
  end

  it "explains that preview checks are a focused excerpt when preview warnings exist" do
    version.assign_source_path_metadata!(source_path: "docs/manual.md", snapshot_kind: "received_markdown")
    version.mark_preview_build_queued!

    get document_version_quality_check_path(version)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("rendered site と build status の warning / error 抜粋です。すべての check は下の一覧で確認してください。")
    expect(page_text).to include("Preview build is queued")
    expect(page_text).to include("Markdown preview site is not built yet")
  end
end
