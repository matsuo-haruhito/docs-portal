require "rails_helper"

RSpec.describe "Document comment workspace action grouping", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "COMMENT-ACTIONS", name: "Comment Action Project") }
  let(:document) { create(:document, project:, title: "Comment Action Manual", slug: "comment-action-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "separates Q&A replies from status updates for admins" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can partners follow this procedure?"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Confirm the internal note before publishing."
    )

    sign_in_as(admin_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    page_text = Nokogiri::HTML(response.body).text.squish

    expect(page_text).to include("Q&Aへの返信")
    expect(page_text).to include("返信はこのQ&Aスレッドに追加され、質問の状態は変更しません")
    expect(page_text).to include("Q&Aの状態を更新")
    expect(page_text).to include("回答済みは回答・対応が終わった質問")
    expect(page_text).to include("クローズは対応しない・受付を閉じる質問")
    expect(page_text).to include("確認事項の状態を更新")
    expect(page_text).to include("解決は内部レビューコメントの対応完了を示します")
    expect(page_text).to include("Q&Aの回答状態とは別に扱います")
    expect(page_text).to include("回答済みにする")
    expect(page_text).to include("クローズする")
    expect(page_text).to include("解決")
  end

  it "keeps internal review actions and admin status actions hidden from external users" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can partners follow this procedure?"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Internal-only status action context."
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    page_text = Nokogiri::HTML(response.body).text.squish

    expect(page_text).to include("Q&Aへの返信")
    expect(page_text).to include("返信はこのQ&Aスレッドに追加され、質問の状態は変更しません")
    expect(page_text).not_to include("Q&Aの状態を更新")
    expect(page_text).not_to include("回答済みにする")
    expect(page_text).not_to include("クローズする")
    expect(page_text).not_to include("確認事項の状態を更新")
    expect(page_text).not_to include("解決は内部レビューコメントの対応完了")
    expect(page_text).not_to include("Internal-only status action context")
  end
end
