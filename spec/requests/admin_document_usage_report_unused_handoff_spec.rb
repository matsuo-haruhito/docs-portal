require "rails_helper"

RSpec.describe "Admin document usage report unused handoff", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "UNUSED", name: "Unused Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def handoff_digest
    parsed_html.at_css(%(textarea[name="document_usage_report_unused_handoff_digest"]))&.text.to_s
  end

  def action_labels
    parsed_html.css("a, button, input[type='submit']").map do |node|
      node["value"].presence || node.text.squish
    end
  end

  it "shows a bounded read-only handoff digest for unused filtered reports" do
    used_document = create(:document, project:, title: "Policy Active", slug: "policy-active")
    unused_documents = 6.times.map do |index|
      create(:document, project:, title: "Policy Draft #{index}", slug: "policy-draft-#{index}")
    end
    create(
      :access_log,
      project:,
      document: used_document,
      user: viewer,
      company:,
      action_type: :view,
      accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0)
    )

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      usage_filter: "unused",
      q: "policy",
      from: "2026-05-01",
      to: "2026-05-03"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("未利用文書 handoff")
    expect(page_text).to include("read-only digest")
    expect(page_text).to include("不要・削除・archive 確定ではありません")

    expect(handoff_digest).to include("# 未利用文書 handoff")
    expect(handoff_digest).to include("- 案件: UNUSED / Unused Project")
    expect(handoff_digest).to include("- 期間: 2026-05-01 から 2026-05-03 まで")
    expect(handoff_digest).to include("- 利用状況: 未利用")
    expect(handoff_digest).to include("- 並び順: タイトル順")
    expect(handoff_digest).to include("- 検索: policy")
    expect(handoff_digest).to include("- 表示中の未利用文書: 6件")
    expect(handoff_digest).to include("- 代表行: 先頭5件")
    expect(handoff_digest).to include("Policy Draft 0")
    expect(handoff_digest).to include("slug: policy-draft-0")
    expect(handoff_digest).to include("Policy Draft 4")
    expect(handoff_digest).not_to include("Policy Draft 5")
    expect(handoff_digest).not_to include("Policy Active")
    expect(unused_documents.map(&:slug)).to include("policy-draft-5")

    expect(action_labels).to include("集計", "CSV出力", "JSON metadataを確認")
    expect(action_labels).not_to include("削除", "archive", "アーカイブ")
  end

  it "does not show the unused handoff digest for all or used filters" do
    document = create(:document, project:, title: "Policy Active", slug: "policy-active")
    create(
      :access_log,
      project:,
      document:,
      user: viewer,
      company:,
      action_type: :view,
      accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0)
    )

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(handoff_digest).to be_blank
    expect(page_text).not_to include("未利用文書 handoff")

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "used")

    expect(response).to have_http_status(:ok)
    expect(handoff_digest).to be_blank
    expect(page_text).not_to include("未利用文書 handoff")
  end
end
