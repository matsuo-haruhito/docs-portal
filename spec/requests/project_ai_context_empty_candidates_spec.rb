require "rails_helper"

RSpec.describe "Project AI context empty document candidates", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AIEMPTY", name: "AI Empty Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "ai-empty@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, visibility_policy: :restricted_external)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md", search_body_text: "#{title} body")
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :view) unless visibility_policy == :internal_only
    document
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_href(label)
    parsed_html.css("a").find { _1.text.squish == label }&.fetch("href")
  end

  it "distinguishes a document search with no matching visible candidates" do
    create_exportable_document(title: "Visible Manual", slug: "visible-manual")
    sign_in_as(external_user)

    get project_ai_context_path(project, document_q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の候補: 0件 / 検索結果: 0件 / 閲覧可能: 1件")
    expect(page_text).to include("検索条件: missing")
    expect(page_text).to include("検索条件に一致する閲覧可能な文書はありません。検索語を見直すか、すべての文書に戻してください。")
    expect(link_href("すべての文書に戻す")).to eq(project_ai_context_path(project, mode: "compact"))
    expect(parsed_html.css("fieldset.filter-fieldset label.check-field")).to be_empty
  end

  it "explains when selected documents are no longer visible to the current viewer" do
    hidden = create_exportable_document(title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :internal_only)
    sign_in_as(external_user)

    get project_ai_context_path(project, document_ids: [hidden.id], candidate_view: "selected")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("候補表示: 選択済みのみ / 表示中: 0件 / 選択済み候補: 0件 / 閲覧可能: 0件")
    expect(page_text).to include("選択済み確認: 0件の閲覧可能な選択文書を保持しています。")
    expect(page_text).to include("選択済み表示で確認できる閲覧可能な文書はありません。選択した文書が権限または公開状態の変更で出力対象から外れた可能性があります。")
    expect(page_text).to include("検索候補へ戻るか、すべての文書に戻して対象範囲を確認してください。")
    expect(link_href("検索候補へ戻る")).to include("document_ids%5B%5D=#{hidden.id}")
  end

  it "describes the project-wide no-visible-document state without implying a search miss" do
    sign_in_as(external_user)

    get project_ai_context_path(project)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の候補: 0件 / 閲覧可能: 0件")
    expect(page_text).to include("この案件で現在閲覧可能な文書はありません。文書の登録、公開状態、または閲覧権限を確認してください。")
    expect(page_text).not_to include("検索条件に一致する閲覧可能な文書はありません。")
    expect(link_href("すべての文書に戻す")).to eq(project_ai_context_path(project, mode: "compact"))
  end
end
