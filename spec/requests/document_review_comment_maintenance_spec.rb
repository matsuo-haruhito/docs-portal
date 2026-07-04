require "rails_helper"

RSpec.describe "Document review comment maintenance mode", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:admin_user) { create(:user, :admin) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "COMMENTMAINT", name: "Comment Maintenance Project") }
  let(:document) { create(:document, project:, title: "Comment Maintenance Manual", slug: "comment-maintenance", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  around do |example|
    original_value = ENV.fetch("READ_ONLY_MAINTENANCE", nil)
    example.run
  ensure
    if original_value.nil?
      ENV.delete("READ_ONLY_MAINTENANCE")
    else
      ENV["READ_ONLY_MAINTENANCE"] = original_value
    end
  end

  it "does not create Q&A or review comments during maintenance" do
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    sign_in_as(external_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        comment_tab: "qa",
        comment_q: "maintenance question",
        document_review_comment: {
          comment_type: "question",
          internal_only: "0",
          body: "Can I ask this during maintenance?"
        }
      }
    end.not_to change(DocumentReviewComment, :count)

    expect(response).to redirect_to(project_document_path(project, document.slug, comment_tab: "qa", comment_q: "maintenance question"))
    expect(flash[:alert]).to include("メンテナンス中")
  end

  it "does not resolve or close existing comments during maintenance" do
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Please keep this open during maintenance."
    )
    sign_in_as(admin_user)

    expect do
      patch document_version_document_review_comment_path(version, question), params: {
        decision: "resolve",
        comment_tab: "unresolved",
        comment_q: "keep open"
      }
    end.not_to change { question.reload.status }

    aggregate_failures do
      expect(question).to be_open
      expect(question.resolved_by).to be_nil
      expect(question.resolved_at).to be_nil
      expect(response).to redirect_to(document_version_path(version, comment_tab: "unresolved", comment_q: "keep open"))
      expect(flash[:alert]).to include("メンテナンス中")
    end
  end

  it "keeps the document comment workspace readable during maintenance" do
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Existing public Q&A stays visible."
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Existing internal review note stays visible."
    )
    sign_in_as(internal_user)

    get project_document_path(project, document.slug, comment_tab: "unresolved")

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Existing public Q&A stays visible.")
      expect(response.body).to include("Existing internal review note stays visible.")
    end
  end

  it "keeps the existing create and status update flow when maintenance is off" do
    ENV["READ_ONLY_MAINTENANCE"] = "false"
    sign_in_as(internal_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "request_change",
          body: "Please check this after maintenance."
        }
      }
    end.to change(DocumentReviewComment, :count).by(1)

    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can this be resolved after maintenance?"
    )
    sign_in_as(admin_user)

    patch project_document_document_review_comment_path(project, document, question), params: { decision: "resolve" }

    expect(question.reload).to be_resolved
  end
end
