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

  def author_option_texts
    parsed_html.css('select[name="comment_author_id"] option').map { |option| option.text.squish }
  end

  def tab_href(tab_label)
    parsed_html.css("a.document-comment-tabs__tab-link").find { |link| link.text.squish == tab_label }["href"]
  end

  def parsed_query(href)
    Rack::Utils.parse_nested_query(URI.parse(href).query)
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
    expect(review_panel_text).to include("絞り込み条件に一致する確認事項はありません")
    expect(review_panel_text).not_to include(review_comment.body)

    get project_document_path(project, document.slug, comment_q: "Internal Beta Reviewer")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include("絞り込み条件に一致するQ&Aはありません")
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
    hidden_question_author = create(:user, :internal, name: "Hidden Question Author")
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
    hidden_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: hidden_question_author,
      comment_type: :question,
      internal_only: true,
      body: "Hidden question body should stay private"
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
    expect(qa_panel_text).not_to include(hidden_question.body)
    expect(qa_panel_text).not_to include("Hidden Question Author")

    get project_document_path(project, document.slug, comment_q: "Hidden Review Author")

    expect(response).to have_http_status(:ok)
    expect(all_panel_text).to include("絞り込み条件に一致するQ&Aはありません")
    expect(all_panel_text).not_to include(hidden_review.body)
    expect(all_panel_text).not_to include("Hidden Review Author")
    expect(all_panel_text).not_to include("docs/hidden-review.md")
    expect(all_panel_text).not_to include("確認事項")

    get project_document_path(project, document.slug, comment_q: "Hidden Question Author")

    expect(response).to have_http_status(:ok)
    expect(all_panel_text).to include("絞り込み条件に一致するQ&Aはありません")
    expect(all_panel_text).not_to include(hidden_question.body)
    expect(all_panel_text).not_to include("Hidden Question Author")

    get project_document_path(project, document.slug, comment_q: "v9.4-search")

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(public_question.body)
    expect(qa_panel_text).to include("v9.4-search")
    expect(qa_panel_text).not_to include(hidden_review.body)
    expect(qa_panel_text).not_to include(hidden_question.body)
    expect(visible_reply).to be_present
    expect(hidden_question).to be_present
  end

  it "lets internal users filter comments by visible root and reply authors while preserving tab and query context" do
    qa_author = create(:user, :external, company:, name: "Partner Gamma Author")
    reply_author = create(:user, :internal, name: "Support Delta Replier")
    review_author = create(:user, :internal, name: "Internal Epsilon Reviewer")
    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: qa_author,
      comment_type: :question,
      internal_only: false,
      body: "Shared context marker for author filter"
    )
    reply = create(
      :document_review_comment,
      document:,
      document_version: version,
      parent: question,
      author: reply_author,
      comment_type: :question,
      internal_only: false,
      body: "Reply by selected support user"
    )
    review_comment = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: review_author,
      comment_type: :request_change,
      internal_only: true,
      body: "Review marker for author filter"
    )

    sign_in_as(admin_user)

    get project_document_path(
      project,
      document.slug,
      comment_tab: "qa",
      comment_q: "Shared context marker",
      comment_author_id: reply_author.public_id
    )

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(question.body)
    expect(qa_panel_text).to include(reply.body)
    expect(review_panel_text).to include("絞り込み条件に一致する確認事項はありません")
    expect(author_option_texts).to include("Partner Gamma Author", "Support Delta Replier", "Internal Epsilon Reviewer")
    expect(parsed_query(tab_href("確認事項"))).to include(
      "comment_q" => "Shared context marker",
      "comment_author_id" => reply_author.public_id,
      "comment_tab" => "review"
    )
    expect(parsed_html.css('input[name="comment_author_id"]').map { |input| input["value"] }).to include(reply_author.public_id)

    get project_document_path(project, document.slug, comment_tab: "review", comment_author_id: review_author.public_id)

    expect(response).to have_http_status(:ok)
    expect(review_panel_text).to include(review_comment.body)
    expect(qa_panel_text).to include("絞り込み条件に一致するQ&Aはありません")
  end

  it "keeps external author filter options and results scoped to visible public Q&A and replies" do
    public_author = create(:user, :external, company:, name: "Public Filter Author")
    visible_reply_author = create(:user, :internal, name: "Visible Support Replier")
    hidden_review_author = create(:user, :internal, name: "Private Review Filter Author")
    public_question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: public_author,
      comment_type: :question,
      internal_only: false,
      body: "Public author filter question"
    )
    visible_reply = create(
      :document_review_comment,
      document:,
      document_version: version,
      parent: public_question,
      author: visible_reply_author,
      comment_type: :question,
      internal_only: false,
      body: "Visible public reply for author filter"
    )
    hidden_review = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: hidden_review_author,
      comment_type: :request_change,
      internal_only: true,
      body: "Private author filter review",
      source_path: "docs/private-author-filter.md"
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(author_option_texts).to include("Public Filter Author", "Visible Support Replier")
    expect(author_option_texts).not_to include("Private Review Filter Author")

    get project_document_path(project, document.slug, comment_author_id: visible_reply_author.public_id)

    expect(response).to have_http_status(:ok)
    expect(qa_panel_text).to include(public_question.body)
    expect(qa_panel_text).to include(visible_reply.body)
    expect(all_panel_text).not_to include(hidden_review.body)
    expect(all_panel_text).not_to include("Private Review Filter Author")
    expect(all_panel_text).not_to include("docs/private-author-filter.md")
    expect(all_panel_text).not_to include("確認事項")

    get project_document_path(project, document.slug, comment_author_id: hidden_review_author.public_id)

    expect(response).to have_http_status(:ok)
    expect(all_panel_text).to include(public_question.body)
    expect(all_panel_text).not_to include(hidden_review.body)
    expect(author_option_texts).not_to include("Private Review Filter Author")
  end

  it "preserves a visible author filter after replying to a Q&A thread" do
    qa_author = create(:user, :external, company:, name: "Context Author")
    question = create(
      :document_review_comment,
      document:,
      document_version: version,
      author: qa_author,
      comment_type: :question,
      internal_only: false,
      body: "Context preserving question"
    )

    sign_in_as(admin_user)

    post "/projects/#{project.code}/documents/#{document.slug}/document_review_comments",
      params: {
        comment_tab: "qa",
        comment_q: "Context preserving",
        comment_author_id: qa_author.public_id,
        document_review_comment: {
          comment_type: "question",
          internal_only: false,
          parent_id: question.id,
          document_version_id: version.id,
          body: "Reply keeps the author filter"
        }
      }

    expect(response).to have_http_status(:found)
    expect(parsed_query(response.location)).to include(
      "comment_tab" => "qa",
      "comment_q" => "Context preserving",
      "comment_author_id" => qa_author.public_id
    )
  end
end
