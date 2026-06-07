require "rails_helper"

RSpec.describe "Document comment workspace search fields", type: :request do
  let(:company) { create(:company) }
  let(:admin_user) { create(:user, :internal, name: "Admin Searcher") }
  let(:external_user) { create(:user, :external, company:, name: "External Viewer") }
  let(:project) { create(:project, code: "COMMENTSEARCH", name: "Comment Search Project") }
  let(:document) { create(:document, project:, title: "Comment Search Manual", slug: "comment-search-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v9.4-search", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def all_panel_text
    parsed_html.at_css(".document-comment-tabs__panel--all").text.squish
  end

  def qa_panel_text
    parsed_html.at_css(".document-comment-tabs__panel--qa").text.squish
  end

  def review_panel_text
    parsed_html.at_css(".document-comment-tabs__panel--review").text.squish
  end

  it "lets internal users find comments by Q&A author, review author, and version label" do
    qa_author = create(:user, :external, company:, name: "Partner Alpha Author")
    review_author = create(:user, :internal, name: "Internal Beta Reviewer")
    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: qa_author,
      comment_type: :question,
      internal_only: false,
      body: "Question body without the author keyword"
    )
    review_comment = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: review_author,
      comment_type: :request_change,
      internal_only: true,
      body: "Review body without the author keyword"
    )

    sign_in_as(admin_user)

    get project_document_path(project, document.slug, comment_q: "Partner Alpha Author")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(question.body)
    expect(review_panel_text).to include("検索条件に一致する確認事項はありません")
    expect(review_panel_text).not_to include(review_comment.body)

    get project_document_path(project, document.slug, comment_q: "Internal Beta Reviewer")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include("検索条件に一致するQ&Aはありません")
    expect(review_panel_text).to include(review_comment.body)
    expect(review_panel_text).not_to include(question.body)

    get project_document_path(project, document.slug, comment_q: "v9.4-search")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(question.body)
    expect(review_panel_text).to include(review_comment.body)
  end

  it "keeps external search limited to visible Q&A author, visible reply author, and visible version label" do
    public_author = create(:user, :external, company:, name: "Partner Visible Author")
    visible_reply_author = create(:user, :internal, name: "Support Visible Author")
    hidden_reply_author = create(:user, :internal, name: "Hidden Reply Author")
    hidden_review_author = create(:user, :internal, name: "Hidden Review Author")
    public_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: public_author,
      comment_type: :question,
      internal_only: false,
      body: "Public question body without author keywords"
    )
    visible_reply = create(
      :document_review_comment,
      document:,
      document_version: version,
      parent: public_question,
      author: visible_reply_author,
      comment_type: :question,
      internal_only: false,
      body: "Visible reply body without author keywords"
    )
    hidden_reply = create(
      :document_review_comment,
      document:,
      document_version: version,
      parent: public_question,
      author: hidden_reply_author,
      comment_type: :question,
      internal_only: true,
      body: "Hidden reply body should stay private"
    )
    hidden_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: hidden_review_author,
      comment_type: :request_change,
      internal_only: true,
      body: "Hidden review body should stay private",
      source_path: "docs/hidden-review.md"
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug, comment_q: "Partner Visible Author")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(public_question.body)
    expect(qa_panel_text).to include("Partner Visible Author")
    expect(qa_panel_text).not_to include(hidden_review.body)

    get project_document_path(project, document.slug, comment_q: "Support Visible Author")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(public_question.body)
    expect(qa_panel_text).to include(visible_reply.body)
    expect(qa_panel_text).to include("Support Visible Author")
    expect(qa_panel_text).not_to include(hidden_reply.body)
    expect(qa_panel_text).not_to include("Hidden Reply Author")

    get project_document_path(project, document.slug, comment_q: "Hidden Review Author")

    expect(response).to have_http_status(:ok)
    expect(all_panel_text).to include("検索条件に一致するQ&Aはありません")
    expect(all_panel_text).not_to include(hidden_review.body)
    expect(all_panel_text).not_to include("Hidden Review Author")
    expect(all_panel_text).not_to include("docs/hidden-review.md")
    expect(all_panel_text).not_to include("確認事項")

    get project_document_path(project, document.slug, comment_q: "Hidden Reply Author")

    expect(response).to have_http_status(:ok)
    expect(all_panel_text).to include("検索条件に一致するQ&Aはありません")
    expect(all_panel_text).not_to include(hidden_reply.body)
    expect(all_panel_text).not_to include("Hidden Reply Author")

    get project_document_path(project, document.slug, comment_q: "v9.4-search")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(public_question.body)
    expect(qa_panel_text).to include("v9.4-search")
    expect(qa_panel_text).not_to include(hidden_review.body)
    expect(qa_panel_text).not_to include(hidden_reply.body)
    expect(visible_reply).to be_present
    expect(hidden_reply).to be_present
  end
end
