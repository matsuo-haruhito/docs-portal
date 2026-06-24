require "rails_helper"

RSpec.describe "Dashboard open Q&A handoff", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "QA", name: "Q&A Project") }
  let(:internal_user) { create(:user, :internal) }
  let(:external_author) { create(:user, :external, company:, name: "External Sender") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def dashboard_section(title)
    parsed_html.css(".dashboard-grid .card").find do |section|
      section.at_css("h2")&.text&.squish == title
    end
  end

  def dashboard_section_text(title)
    dashboard_section(title).text.squish
  end

  def dashboard_section_links(title)
    dashboard_section(title).css("a")
  end

  it "shows open public root Q&A candidates to internal users only" do
    document = create(:document, project:, title: "Q&A Handbook", slug: "qa-handbook")
    version = create(:document_version, document:, version_label: "v2.0.0")
    open_thread = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_author,
      comment_type: :question,
      internal_only: false,
      status: :open,
      body: "How should we handle invoice approval before month end?"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      parent: open_thread,
      author: internal_user,
      comment_type: :question,
      internal_only: false,
      status: :open,
      body: "We are checking the owner."
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_author,
      comment_type: :question,
      internal_only: false,
      status: :resolved,
      resolved_by: internal_user,
      resolved_at: Time.current,
      body: "Resolved Q&A should not appear"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_author,
      comment_type: :question,
      internal_only: false,
      status: :rejected,
      body: "Closed Q&A should not appear"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :question,
      internal_only: true,
      status: :open,
      body: "Internal-only question should not appear"
    )
    archived_document = create(
      :document,
      project:,
      title: "Archived Secret Q&A",
      slug: "archived-secret-qa",
      archived_at: 1.day.ago
    )
    create(
      :document_review_comment,
      document: archived_document,
      author: external_author,
      comment_type: :question,
      internal_only: false,
      status: :open,
      body: "Archived document metadata should not appear"
    )

    sign_in_as(internal_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)

    handoff_text = dashboard_section_text("受付中Q&A候補")

    aggregate_failures do
      expect(handoff_text).to include(
        "公開Q&Aのうち受付中の root thread を表示します。",
        "Q&A Handbook",
        "Q&A Project（QA）",
        "版 v2.0.0",
        "投稿者 External Sender",
        "返信あり",
        "How should we handle invoice approval before month end?"
      )
      expect(handoff_text).not_to include(
        "Resolved Q&A should not appear",
        "Closed Q&A should not appear",
        "Internal-only question should not appear",
        "Archived Secret Q&A",
        "Archived document metadata should not appear"
      )
      expect(dashboard_section_links("受付中Q&A候補").map { |link| link["href"] }).to include(
        document_version_path(version, comment_tab: "qa")
      )
    end
  end

  it "does not expose the internal handoff section to external users" do
    external_user = create(:user, :external, company:)
    document = create(:document, project:, title: "External Visible Q&A", slug: "external-visible-qa")
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
    create(
      :document_review_comment,
      document:,
      author: external_author,
      comment_type: :question,
      internal_only: false,
      status: :open,
      body: "External users can see this in the workspace, not on dashboard handoff"
    )

    sign_in_as(external_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include(
      "受付中Q&A候補",
      "External users can see this in the workspace, not on dashboard handoff"
    )
  end

  it "explains that an empty internal handoff is not a green notification or SLA signal" do
    sign_in_as(internal_user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(dashboard_section_text("受付中Q&A候補")).to include(
      "受付中Q&A候補はありません。",
      "通知 green、SLA 達成、問い合わせが存在しない保証ではありません。",
      "各文書のQ&A workspaceを確認してください。"
    )
  end
end
