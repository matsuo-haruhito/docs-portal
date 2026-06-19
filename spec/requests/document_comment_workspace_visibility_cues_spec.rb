require "rails_helper"

RSpec.describe "Document comment workspace visibility cues", type: :request do
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

    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can customers see this section?"
    )

    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Internal review should check the approval wording",
      source_path: "docs/review.md"
    )
  end

  it "shows internal users separate public Q&A and internal review cues" do
    sign_in_as(internal_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    page_text = Nokogiri::HTML(response.body).text.squish

    aggregate_failures do
      expect(page_text).to include("外部/利用者にも見えるQ&Aと、内部だけで扱う確認事項をここにまとめます")
      expect(page_text).to include("Q&Aの受付・回答状態と確認事項の解決状態は別の管理です")
      expect(page_text).to include("Q&A（外部/利用者にも表示）")
      expect(page_text).to include("確認事項（内部のみの社内レビューコメント）")
      expect(page_text).to include("公開範囲: 外部/利用者にも表示")
      expect(page_text).to include("公開範囲: 内部のみ")
      expect(page_text).to include("Q&A状態:")
      expect(page_text).to include("確認事項状態:")
    end
  end

  it "keeps external users scoped to public Q&A without internal-only wording" do
    sign_in_as(external_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    page_text = Nokogiri::HTML(response.body).text.squish

    aggregate_failures do
      expect(page_text).to include("文書に関するQ&Aをここにまとめます")
      expect(page_text).to include("Q&A（外部/利用者にも表示）")
      expect(page_text).to include("公開範囲: 外部/利用者にも表示")
      expect(page_text).to include("このスレッドは文書のQ&Aとして表示されます")
      expect(page_text).not_to include("確認事項")
      expect(page_text).not_to include("内部限定")
      expect(page_text).not_to include("内部のみ")
      expect(page_text).not_to include("Internal review should check the approval wording")
      expect(page_text).not_to include("docs/review.md")
    end
  end
end
