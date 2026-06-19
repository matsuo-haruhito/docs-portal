require "rails_helper"

RSpec.describe "Document comment workspace search", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "COMMENT", name: "Comment Project") }
  let(:document) { create(:document, project:, title: "Comment Manual", slug: "comment-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "lets internal users search Q&A body and review location metadata on the document workspace" do
    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Refund deadline question"
    )
    other_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Shipping address question"
    )
    review_comment = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Please check the diagram caption",
      source_path: "docs/payment-flow.md",
      text_anchor_label: "Payment Flow"
    )

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, comment_q: "refund")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("絞り込み条件")
    expect(response.body).to include("refund")
    expect(response.body).to include(question.body)
    expect(response.body).not_to include(other_question.body)
    expect(response.body).not_to include(review_comment.body)

    get project_document_path(project, document.slug, comment_q: "payment-flow")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("絞り込み条件")
    expect(response.body).to include("payment-flow")
    expect(response.body).to include(review_comment.body)
    expect(response.body).to include("docs/payment-flow.md")
    expect(response.body).not_to include(question.body)
    expect(response.body).not_to include(other_question.body)
  end

  it "keeps external comment search inside visible public Q&A" do
    public_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Public onboarding question"
    )
    internal_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Secret launch blocker",
      source_path: "internal/launch-plan.md"
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug, comment_q: "launch")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("絞り込み条件")
    expect(response.body).to include("launch")
    expect(response.body).to include("絞り込み条件に一致するQ&Aはありません。")
    expect(response.body).not_to include(internal_review.body)
    expect(response.body).not_to include("internal/launch-plan.md")
    expect(response.body).not_to include(public_question.body)

    get project_document_path(project, document.slug, comment_q: "onboarding")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(public_question.body)
    expect(response.body).not_to include(internal_review.body)
  end

  it "applies search before the unresolved tab keeps only current unresolved comments" do
    open_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Invoice workflow is still open"
    )
    resolved_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      status: :resolved,
      resolved_by: internal_user,
      resolved_at: 1.hour.ago,
      body: "Invoice workflow already answered"
    )

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, comment_q: "invoice workflow")
    expect(response).to have_http_status(:ok)

    html = Nokogiri::HTML(response.body)
    qa_panel_text = html.at_css(".document-comment-tabs__panel--qa").text
    unresolved_panel_text = html.at_css(".document-comment-tabs__panel--unresolved").text

    expect(qa_panel_text).to include(open_question.body)
    expect(qa_panel_text).to include(resolved_question.body)
    expect(unresolved_panel_text).to include(open_question.body)
    expect(unresolved_panel_text).not_to include(resolved_question.body)
  end

  it "supports the same search on the version workspace" do
    version_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Version specific approval question"
    )
    other_question = create(
      :document_review_comment,
      document:,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Document level only question"
    )

    sign_in_as(internal_user)

    get document_version_path(version, comment_q: "approval")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("絞り込み条件")
    expect(response.body).to include("approval")
    expect(response.body).to include(version_question.body)
    expect(response.body).not_to include(other_question.body)
  end

  it "renders oversized comment search queries with the server-side slice" do
    normalized_query = "a" * DocumentCommentWorkspaceSearch::COMMENT_QUERY_MAX_LENGTH
    raw_tail = "raw-tail-should-not-render"
    oversized_query = "  #{normalized_query}#{raw_tail}  "
    public_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "#{normalized_query} public question"
    )
    internal_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "#{normalized_query} internal note"
    )

    sign_in_as(external_user)

    get document_version_path(version, comment_q: oversized_query)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(maxlength="#{DocumentCommentWorkspaceSearch::COMMENT_QUERY_MAX_LENGTH}"))
    expect(response.body).to include(%(value="#{normalized_query}"))
    expect(response.body).to include("絞り込み条件:")
    expect(response.body).to include(public_question.body)
    expect(response.body).not_to include(raw_tail)
    expect(response.body).not_to include(internal_review.body)
  end
end
