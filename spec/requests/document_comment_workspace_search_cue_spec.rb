require "rails_helper"

RSpec.describe "Document comment workspace search cue", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REVIEW", name: "Review Project") }
  let(:document) { create(:document, project:, title: "Review Manual", slug: "review-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "tells internal users that summary and tab counts are based on the active search result" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Delivery window question should match"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Archive retention question should not match"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Delivery migration handoff note"
    )

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, comment_q: "delivery")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("絞り込み条件: キーワード delivery")
    expect(page_text).to include("表示中の件数とタブの未解決件数は、絞り込み条件に一致したコメントだけを基準にしています。")
    expect(page_text).to include("絞り込みは、すべて / Q&A / 確認事項 / 未解決の各タブに先に適用されます")
  end

  it "keeps the same search-result count cue for external users without exposing internal-only review comments" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Partner rollout question is public"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Partner rollout internal escalation"
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug, comment_q: "internal escalation")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("絞り込み条件: キーワード internal escalation")
    expect(page_text).to include("表示中の件数とタブの未解決件数は、絞り込み条件に一致したコメントだけを基準にしています。")
    expect(page_text).to include("絞り込みは、すべて / Q&A / 未解決Q&A の各タブに先に適用されます")
    expect(page_text).not_to include("Partner rollout internal escalation")
    expect(page_text).not_to include("確認事項")
  end
end
