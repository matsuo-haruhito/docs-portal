require "rails_helper"
require "uri"

RSpec.describe "Document review comment redirect context", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REVIEWCTX", name: "Review Context Project") }
  let(:document) { create(:document, project:, title: "Review Context Manual", slug: "review-context", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "preserves only allowed document-level comment context for internal comment creation" do
    other_document = create(:document, project:, title: "Other Manual", slug: "other-manual", visibility_policy: :restricted_external)

    sign_in_as(internal_user)

    post project_document_document_review_comments_path(project, document), params: {
      comment_tab: "review",
      comment_q: "  migration handoff  ",
      return_to: project_document_path(project, other_document.slug, comment_tab: "review"),
      unrelated: "keep-me-out",
      document_review_comment: {
        comment_type: "request_change",
        body: "Please check the migration handoff."
      }
    }

    expect(response).to have_http_status(:found)
    expect(redirect_path).to eq(project_document_path(project, document.slug))
    expect(redirect_query).to eq("comment_q" => "migration handoff", "comment_tab" => "review")
  end

  it "does not redirect external users into the internal review tab" do
    sign_in_as(external_user)

    post project_document_document_review_comments_path(project, document), params: {
      comment_tab: "review",
      comment_q: "  partner question  ",
      return_to: "https://example.test/unsafe",
      document_review_comment: {
        comment_type: "question",
        internal_only: "1",
        body: "Can partners use this document?"
      }
    }

    expect(response).to have_http_status(:found)
    expect(redirect_path).to eq(project_document_path(project, document.slug))
    expect(redirect_query).to eq("comment_q" => "partner question")
  end

  it "keeps version-level update context bounded to valid tabs and normalized search text" do
    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Should this version stay visible?"
    )
    long_query = "  #{"release-" * 30}  "
    normalized_query = long_query.strip.first(DocumentCommentWorkspaceSearch::COMMENT_QUERY_MAX_LENGTH)

    sign_in_as(admin_user)

    patch document_version_document_review_comment_path(version, question), params: {
      decision: "resolve",
      comment_tab: "unresolved",
      comment_q: long_query,
      return_to: project_document_path(project, document.slug),
      ignored: "not-restored"
    }

    expect(response).to have_http_status(:found)
    expect(redirect_path).to eq(document_version_path(version))
    expect(redirect_query).to eq("comment_q" => normalized_query, "comment_tab" => "unresolved")
    expect(question.reload).to be_resolved
  end

  it "falls back to the bare current document when tab and search context are not safe to restore" do
    question = create(
      :document_review_comment,
      document:,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can this be closed?"
    )

    sign_in_as(admin_user)

    patch project_document_document_review_comment_path(project, document, question), params: {
      decision: "reject",
      comment_tab: "../review",
      comment_q: "   ",
      return_to: "//example.test/review?comment_tab=review",
      other_document_id: create(:document, project:, slug: "outside-context").id
    }

    expect(response).to have_http_status(:found)
    expect(redirect_path).to eq(project_document_path(project, document.slug))
    expect(redirect_query).to eq({})
    expect(question.reload).to be_rejected
  end

  def redirect_uri
    URI.parse(response.location)
  end

  def redirect_path
    redirect_uri.path
  end

  def redirect_query
    Rack::Utils.parse_nested_query(redirect_uri.query.to_s)
  end
end
