require "rails_helper"

RSpec.describe "Document bookmark recent search project code", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_with_text(text)
    parsed_html.css("a").find { |link| link.text.squish == text }
  end

  def grant_access(document)
    create(:project_membership, project: document.project, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def mark_recent(document, accessed_at: Time.current)
    create(
      :access_log,
      user:,
      company:,
      project: document.project,
      document:,
      action_type: :view,
      target_type: "document",
      accessed_at:
    )
  end

  it "filters displayed recent documents by project code while preserving saved shortcut filters" do
    project = create(:project, name: "Alpha Workspace", code: "ALPHA2397")
    other_project = create(:project, name: "Beta Workspace", code: "BETA2397")
    matching_recent_document = create(:document, project:, title: "Quarterly Plan", slug: "quarterly-plan", visibility_policy: :restricted_external)
    other_recent_document = create(:document, project: other_project, title: "Operations Guide", slug: "operations-guide", visibility_policy: :restricted_external)
    saved_document = create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external)

    [matching_recent_document, other_recent_document, saved_document].each { |document| grant_access(document) }
    create(:document_bookmark, user:, document: saved_document, bookmark_type: :favorite)
    mark_recent(matching_recent_document, accessed_at: 2.minutes.ago)
    mark_recent(other_recent_document, accessed_at: 1.minute.ago)
    sign_in_as(user)

    get document_bookmarks_path, params: {
      project_code: project.code,
      bookmark_q: "manual",
      recent_q: "alpha2397"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Quarterly Plan")
    expect(response.body).to include("Alpha Workspace")
    expect(response.body).not_to include("Operations Guide")
    expect(response.body).to include("最近見た文書検索「alpha2397」は、表示中の最大 20 件だけを絞り込んでいます。保存済みショートカットの条件は維持されます。")
    expect(response.body).to include("文書名・案件名・案件コードに一致します")
    expect(response.body).to include("文書名・案件名で検索・案件コードも可")

    recent_clear_link = link_with_text("最近見た条件をクリア")
    expect(recent_clear_link).to be_present
    expect(recent_clear_link["href"]).to include("project_code=#{project.code}")
    expect(recent_clear_link["href"]).to include("bookmark_q=manual")
    expect(recent_clear_link["href"]).not_to include("recent_q")
  end

  it "shows next-step links when a recent search misses the displayed twenty-item history" do
    project = create(:project, name: "Visible Project", code: "VISIBLE")
    recent_document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    grant_access(recent_document)
    mark_recent(recent_document)
    sign_in_as(user)

    get document_bookmarks_path, params: { recent_q: "not-found" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最近見た文書検索「not-found」に一致する文書は、最近表示された最大 20 件内にありません。検索語を変えるか、案件一覧から文書を探してください。")
    expect(response.body).to include("最近見た条件をクリアして表示中の履歴を確認することもできます。")
    expect(link_with_text("最近見た条件をクリア")).to be_present
    expect(link_with_text("案件一覧から探す")).to be_present
    expect(link_with_text("文書一覧から探す")).to be_present
    expect(response.body).not_to include("Guide")
  end
end
