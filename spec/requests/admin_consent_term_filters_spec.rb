require "rails_helper"

RSpec.describe "Admin consent term filters", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_consent_term(title:, version_label:, active: true, consent_scope: :project, requirement_timing: :first_view)
    ConsentTerm.create!(
      title:,
      version_label:,
      body: "同意本文 #{title} #{version_label}",
      active:,
      consent_scope:,
      requirement_timing:
    )
  end

  before do
    sign_in_as(create(:user, :internal))
  end

  it "searches consent terms by title and version label" do
    title_match = create_consent_term(title: "閲覧同意", version_label: "2026-01")
    version_match = create_consent_term(title: "配布同意", version_label: "archive-2025")
    create_consent_term(title: "外部共有同意", version_label: "v1")

    get admin_consent_terms_path, params: { q: "閲覧" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(title_match.title)
    expect(page_text).not_to include(version_match.title)
    expect(response.body).to include("同意文面一覧の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="title"')

    get admin_consent_terms_path, params: { q: "archive" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(version_match.title)
    expect(page_text).not_to include(title_match.title)
  end

  it "filters by active state, consent scope, and requirement timing" do
    active_project = create_consent_term(
      title: "案件初回同意",
      version_label: "v1",
      active: true,
      consent_scope: :project,
      requirement_timing: :first_view
    )
    inactive_global = create_consent_term(
      title: "全体改訂同意",
      version_label: "v1",
      active: false,
      consent_scope: :global,
      requirement_timing: :every_version_change
    )
    download_term = create_consent_term(
      title: "ダウンロード同意",
      version_label: "v1",
      active: true,
      consent_scope: :download,
      requirement_timing: :every_download
    )

    get admin_consent_terms_path, params: { active: "false" }

    expect(page_text).to include(inactive_global.title)
    expect(page_text).not_to include(active_project.title)
    expect(page_text).not_to include(download_term.title)

    get admin_consent_terms_path, params: { consent_scope: "download" }

    expect(page_text).to include(download_term.title)
    expect(page_text).not_to include(active_project.title)
    expect(page_text).not_to include(inactive_global.title)

    get admin_consent_terms_path, params: { requirement_timing: "every_version_change" }

    expect(page_text).to include(inactive_global.title)
    expect(page_text).not_to include(active_project.title)
    expect(page_text).not_to include(download_term.title)
  end

  it "combines q and filters with AND semantics" do
    visible_match = create_consent_term(
      title: "利用規約",
      version_label: "v2",
      active: false,
      consent_scope: :project,
      requirement_timing: :every_version_change
    )
    create_consent_term(
      title: "利用規約",
      version_label: "v1",
      active: true,
      consent_scope: :project,
      requirement_timing: :every_version_change
    )
    create_consent_term(
      title: "利用補足",
      version_label: "v1",
      active: false,
      consent_scope: :global,
      requirement_timing: :every_version_change
    )

    get admin_consent_terms_path, params: {
      q: "利用",
      active: "false",
      consent_scope: "project",
      requirement_timing: "every_version_change"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(visible_match.title)
    expect(page_text).to include(visible_match.version_label)
    expect(page_text).not_to include("利用規約 v1")
    expect(page_text).not_to include("利用補足")
    expect(page_text).to include("条件をリセット")
  end

  it "ignores unsupported filter values instead of failing" do
    first = create_consent_term(title: "基本同意", version_label: "v1", consent_scope: :project)
    second = create_consent_term(title: "共有同意", version_label: "v1", consent_scope: :shared_link)

    get admin_consent_terms_path, params: {
      active: "maybe",
      consent_scope: "unsupported",
      requirement_timing: "later"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(first.title)
    expect(page_text).to include(second.title)
  end

  it "distinguishes filtered empty results from the initial empty state" do
    create_consent_term(title: "基本同意", version_label: "v1")

    get admin_consent_terms_path, params: { q: "not-found" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する同意文面はありません。")
    expect(page_text).not_to include("まだ同意文面はありません。")
  end

  it "keeps the initial empty state when there are no consent terms" do
    get admin_consent_terms_path, params: { q: "not-found" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ同意文面はありません。")
    expect(page_text).not_to include("条件に一致する同意文面はありません。")
  end
end
