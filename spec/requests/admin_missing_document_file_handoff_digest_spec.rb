require "rails_helper"

RSpec.describe "Admin missing document file handoff digest", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "MISS", name: "Missing Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def handoff_digest
    parsed_html.at_css(%(textarea[name="missing_document_file_handoff_digest"]))&.text.to_s
  end

  def missing_file_for(document, file_name:, storage_key:)
    version = create(:document_version, document:)
    create(:document_file, document_version: version, file_name:, storage_key:)
  end

  it "shows a bounded read-only Markdown digest for unfiltered missing files" do
    document = create(:document, project:, title: "Operations Runbook", slug: "ops-runbook")
    files = 6.times.map do |index|
      missing_file_for(
        document,
        file_name: "handoff-#{index}.pdf",
        storage_key: "manuals/handoff-#{index}.pdf"
      )
    end

    sign_in_as(admin_user)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("引き継ぎ用Markdown digest")
    expect(handoff_digest).to include("# 欠落文書ファイル handoff")
    expect(handoff_digest).to include("- 案件: 未指定")
    expect(handoff_digest).to include("- 文書: 未指定")
    expect(handoff_digest).to include("- ファイル: 未指定")
    expect(handoff_digest).to include("- 登録ファイル数: 6")
    expect(handoff_digest).to include("- 全体欠落数: 6")
    expect(handoff_digest).to include("- 条件一致欠落数: 6")
    expect(handoff_digest).to include("- 表示上限: 先頭100件")
    expect(handoff_digest).to include("- 表示中件数: 6")
    expect(handoff_digest).to include("代表 missing file（表示中先頭5件）")
    expect(handoff_digest).to include("handoff-0.pdf")
    expect(handoff_digest).to include("storage/document_files/manuals/handoff-0.pdf")
    expect(handoff_digest).to include("handoff-4.pdf")
    expect(handoff_digest).not_to include("handoff-5.pdf")
    expect(handoff_digest).to include("自動修復、削除、再import、CSV export は行いません")
    expect(handoff_digest).to include("raw absolute path や storage backend private path は含めません")
    expect(handoff_digest).not_to include(files.first.absolute_path.to_s)
    expect(handoff_digest).not_to include(Rails.root.to_s)
  end

  it "includes active filters and matching counts in the digest" do
    matching_document = create(:document, project:, title: "Safety Runbook", slug: "safety-runbook")
    other_document = create(:document, project: other_project, title: "Safety Runbook", slug: "safety-other")
    missing_file_for(matching_document, file_name: "handoff.pdf", storage_key: "manuals/safety/handoff.pdf")
    missing_file_for(other_document, file_name: "handoff.pdf", storage_key: "manuals/safety/other-handoff.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(project_id: project.id, document_q: "safety", file_q: "handoff")

    expect(response).to have_http_status(:ok)
    expect(handoff_digest).to include("- 案件: MISS / Missing Project")
    expect(handoff_digest).to include("- 文書: safety")
    expect(handoff_digest).to include("- ファイル: handoff")
    expect(handoff_digest).to include("- 登録ファイル数: 2")
    expect(handoff_digest).to include("- 全体欠落数: 2")
    expect(handoff_digest).to include("- 条件一致欠落数: 1")
    expect(handoff_digest).to include("Missing Project / Safety Runbook")
    expect(handoff_digest).to include("storage/document_files/manuals/safety/handoff.pdf")
    expect(handoff_digest).not_to include("Other Project")
  end

  it "keeps filtered zero results distinct from all-clear state" do
    document = create(:document, project:, title: "Visible Manual", slug: "visible-manual")
    missing_file_for(document, file_name: "visible.pdf", storage_key: "visible.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(document_q: "not-found")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する欠落ファイルはありません。全体では1件の実体欠落があります。")
    expect(handoff_digest).to include("- 文書: not-found")
    expect(handoff_digest).to include("- 全体欠落数: 1")
    expect(handoff_digest).to include("- 条件一致欠落数: 0")
    expect(handoff_digest).to include("- 表示中件数: 0")
    expect(handoff_digest).to include("代表 missing file（表示中先頭0件）")
    expect(handoff_digest).to include("- なし")
    expect(handoff_digest).to include("全体欠落や条件一致全件を保証する export ではありません")
    expect(page_text).not_to include("実体ファイルの欠落は検出されていません。")
  end
end
