require "rails_helper"

RSpec.describe "Document comment workspace handoff summary", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "HANDOFF", name: "Handoff Project") }
  let(:document) { create(:document, project:, title: "Handoff Manual", slug: "handoff-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "lets internal users copy unresolved public Q&A and internal-only review summaries without exposing them externally" do
    open_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can this handoff question stay visible to partners?"
    )
    answered_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      status: :resolved,
      resolved_by: admin_user,
      resolved_at: 1.hour.ago,
      body: "Answered Q&A must not be copied"
    )
    closed_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      status: :rejected,
      body: "Closed Q&A must not be copied"
    )
    review_comment = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Internal-only unresolved review should be handed off safely",
      source_path: "docs/review-handoff.md"
    )
    resolved_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :issue,
      internal_only: true,
      status: :resolved,
      resolved_by: admin_user,
      resolved_at: 1.hour.ago,
      body: "Resolved internal review must not be copied"
    )

    sign_in_as(admin_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    handoff = html.at_css("#document-comment-handoff-summary").text

    expect(html.text).to include("未解決handoff")
    expect(handoff).to include("文書コメント 未解決handoff")
    expect(handoff).to include("/projects/HANDOFF/documents/handoff-manual?comment_tab=unresolved")
    expect(handoff).to include("## 公開Q&A（未解決 1件）")
    expect(handoff).to include("状態: 受付中")
    expect(handoff).to include("投稿者: #{external_user.display_name}")
    expect(handoff).to include("版: v1.0.0")
    expect(handoff).to include(open_question.body)
    expect(handoff).to include("## 内部限定確認事項（未解決 1件）")
    expect(handoff).to include("状態: 未対応")
    expect(handoff).to include("種別: request_change")
    expect(handoff).to include("位置: docs/review-handoff.md")
    expect(handoff).to include(review_comment.body)
    expect(handoff).not_to include(answered_question.body)
    expect(handoff).not_to include(closed_question.body)
    expect(handoff).not_to include(resolved_review.body)

    sign_in_as(external_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    external_html = Nokogiri::HTML(response.body)
    external_text = external_html.text

    expect(external_html.at_css("#document-comment-handoff-summary")).to be_nil
    expect(external_text).not_to include("未解決handoff")
    expect(external_text).not_to include("内部限定確認事項")
    expect(external_text).not_to include(review_comment.body)
    expect(external_text).not_to include("docs/review-handoff.md")
  end

  it "uses the current comment search context for the copyable handoff summary" do
    matching_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Migration handoff question should match"
    )
    missing_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Billing question should not match"
    )
    matching_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :issue,
      internal_only: true,
      body: "Review the migration evidence",
      source_path: "docs/migration-handoff.md"
    )
    missing_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Review the glossary wording"
    )

    sign_in_as(admin_user)

    get project_document_path(project, document.slug, comment_q: "migration-handoff", comment_tab: "review")

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    handoff = html.at_css("#document-comment-handoff-summary").text

    expect(handoff).to include("文脈: 現在の検索/投稿者絞り込み適用中")
    expect(handoff).to include("comment_q=migration-handoff")
    expect(handoff).to include("comment_tab=unresolved")
    expect(handoff).to include("## 内部限定確認事項（未解決 1件）")
    expect(handoff).to include(matching_review.body)
    expect(handoff).to include("docs/migration-handoff.md")
    expect(handoff).not_to include(matching_question.body)
    expect(handoff).not_to include(missing_question.body)
    expect(handoff).not_to include(missing_review.body)
  end

  it "excludes arbitrary request query values from the copyable handoff URL" do
    matching_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Sanitized handoff question should match"
    )

    sign_in_as(admin_user)

    get project_document_path(
      project,
      document.slug,
      comment_q: "Sanitized",
      comment_author_id: external_user.public_id,
      token: "secret-token-value",
      return_to: "https://example.test/after-review?ticket=secret-return",
      access_token: "secret-access-token"
    )

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    handoff = html.at_css("#document-comment-handoff-summary").text

    expect(handoff).to include(matching_question.body)
    expect(handoff).to include("comment_q=Sanitized")
    expect(handoff).to include("comment_author_id=#{external_user.public_id}")
    expect(handoff).to include("comment_tab=unresolved")
    expect(handoff).not_to include("token")
    expect(handoff).not_to include("return_to")
    expect(handoff).not_to include("access_token")
    expect(handoff).not_to include("secret-token-value")
    expect(handoff).not_to include("secret-return")
    expect(handoff).not_to include("secret-access-token")
  end
end
