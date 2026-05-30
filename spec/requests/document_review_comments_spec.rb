require "rails_helper"

RSpec.describe "Document review comments", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:admin_user) { create(:user, :internal) }
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

  it "allows internal users to create review comments on a version" do
    sign_in_as(internal_user)

    expect do
      post document_version_document_review_comments_path(version), params: {
        document_review_comment: {
          comment_type: "request_change",
          body: "Please revise this section."
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    expect(response).to redirect_to(document_version_path(version))
    comment = DocumentReviewComment.order(:id).last
    expect(comment.document).to eq(document)
    expect(comment.document_version).to eq(version)
    expect(comment.author).to eq(internal_user)
  end

  it "allows internal users to create document-level comments with optional location metadata" do
    sign_in_as(internal_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "issue",
          body: "Check this JSON path.",
          text_line_start: 12,
          text_line_end: 18,
          text_anchor_type: "json_path",
          text_anchor_path: "$.screens[0].items[2]",
          source_path: "specs/screens.json"
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    expect(response).to redirect_to(project_document_path(project, document.slug))
    comment = DocumentReviewComment.order(:id).last
    expect(comment.document_version).to be_nil
    expect(comment.text_line_start).to eq(12)
    expect(comment.text_anchor_path).to eq("$.screens[0].items[2]")
    expect(comment.source_path).to eq("specs/screens.json")
  end

  it "shows and resolves comments for internal admins" do
    comment = create(:document_review_comment, document:, document_version: version, author: internal_user, body: "Need more detail")

    sign_in_as(admin_user)

    get document_version_path(version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("社内レビューコメント")
    expect(response.body).to include("Need more detail")
    expect(response.body).to include("解決")

    patch document_version_document_review_comment_path(version, comment), params: { decision: "resolve" }

    expect(response).to redirect_to(document_version_path(version))
    expect(comment.reload).to be_resolved
    expect(comment.resolved_by).to eq(admin_user)
  end

  it "allows external users to create public Q&A threads and internal users to reply" do
    sign_in_as(external_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "question",
          body: "Can we use this procedure next month?"
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    question = DocumentReviewComment.order(:id).last
    expect(question.author).to eq(external_user)
    expect(question.internal_only).to eq(false)
    expect(question.question?).to eq(true)

    sign_in_as(internal_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "question",
          parent_id: question.id,
          body: "Yes. The current published version is valid."
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    reply = DocumentReviewComment.order(:id).last
    expect(reply.parent).to eq(question)
    expect(reply.internal_only).to eq(false)

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Q&A")
    expect(response.body).to include("Can we use this procedure next month?")
    expect(response.body).to include("Yes. The current published version is valid.")
  end

  it "keeps externally submitted Q&A threads public even when visibility params are tampered with" do
    sign_in_as(external_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "question",
          internal_only: "1",
          body: "Can this be shared with partners?"
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    question = DocumentReviewComment.order(:id).last
    expect(question.author).to eq(external_user)
    expect(question).to be_question
    expect(question.internal_only).to eq(false)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "request_change",
          internal_only: "1",
          parent_id: question.id,
          body: "Please treat this as public follow-up."
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    reply = DocumentReviewComment.order(:id).last
    expect(reply.parent).to eq(question)
    expect(reply).to be_question
    expect(reply.internal_only).to eq(false)
  end

  it "prevents replies from crossing internal visibility or document boundaries" do
    internal_parent = create(:document_review_comment, document:, document_version: version, author: internal_user, body: "Internal parent")
    other_document = create(:document, project:, title: "Other Manual", slug: "other-manual", visibility_policy: :restricted_external)
    other_parent = create(:document_review_comment, document: other_document, author: internal_user, body: "Other document question", internal_only: false, comment_type: :question)

    sign_in_as(external_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "question",
          parent_id: internal_parent.id,
          body: "This must not attach to an internal thread."
        }
      }
    end.not_to change(DocumentReviewComment, :count)
    expect(response).to redirect_to(project_document_path(project, document.slug))

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "question",
          parent_id: other_parent.id,
          body: "This must not attach to another document."
        }
      }
    end.not_to change(DocumentReviewComment, :count)
    expect(response).to redirect_to(project_document_path(project, document.slug))
  end

  it "uses the route document version and rejects tampered version ids from another document" do
    other_document = create(:document, project:, title: "Versioned Other Manual", slug: "versioned-other-manual", visibility_policy: :restricted_external)
    other_version = create(:document_version, document: other_document, version_label: "v2.0.0", status: :published)

    sign_in_as(internal_user)

    expect do
      post document_version_document_review_comments_path(version), params: {
        document_review_comment: {
          comment_type: "issue",
          document_version_id: other_version.id,
          body: "This must stay on the routed version."
        }
      }
    end.not_to change(DocumentReviewComment, :count)
    expect(response).to redirect_to(document_version_path(version))

    expect do
      post document_version_document_review_comments_path(version), params: {
        document_review_comment: {
          comment_type: "issue",
          body: "This belongs to the routed version."
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    comment = DocumentReviewComment.order(:id).last
    expect(comment.document).to eq(document)
    expect(comment.document_version).to eq(version)
  end

  it "hides review comments from external users and forbids create/update" do
    comment = create(:document_review_comment, document:, document_version: version, author: internal_user, body: "Internal only")

    sign_in_as(external_user)

    get document_version_path(version)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("社内レビューコメント")
    expect(response.body).not_to include("Internal only")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("社内レビューコメント")
    expect(response.body).not_to include("Internal only")

    post document_version_document_review_comments_path(version), params: {
      document_review_comment: {
        comment_type: "note",
        body: "I should not be allowed"
      }
    }
    expect(response).to have_http_status(:forbidden)

    patch document_version_document_review_comment_path(version, comment), params: { decision: "resolve" }
    expect(response).to have_http_status(:forbidden)
  end
end
