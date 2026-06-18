require "rails_helper"

RSpec.describe "Consent history filters", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:other_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "CONSENT", name: "Consent Project") }
  let(:document) { create(:document, project:, title: "Consent Document", slug: "consent-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "manual.pdf") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def section_text(heading)
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == heading }&.text&.squish
  end

  def consent_history_rows
    history = parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == "自分の同意履歴" }
    history.css("tbody tr").map { |row| row.css("td").map { _1.text.squish } }
  end

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :download)
    document.update!(latest_version: version)
  end

  it "filters the current user's history by title, agreed version, and target display without hiding active terms" do
    active_term = create(:consent_term, title: "Active Consent Terms", body: "Active body", version_label: "v-active", consent_scope: :global)
    project_term = create(:consent_term, title: "Project Review Terms", version_label: "release-2026", consent_scope: :project, active: false)
    document_term = create(:consent_term, title: "Document Reading Terms", version_label: "doc-v2", consent_scope: :document, active: false)
    other_term = create(:consent_term, title: "Other User Project Review Terms", version_label: "release-2026", consent_scope: :project, active: false)

    create(:user_consent, user:, consent_term: project_term, target: project, consent_term_version_label: "release-2026")
    create(:user_consent, user:, consent_term: document_term, target: document, consent_term_version_label: "doc-v2")
    create(:user_consent, user: other_user, consent_term: other_term, target: project, consent_term_version_label: "release-2026")

    sign_in_as(user)

    get consents_path, params: { q: "release-2026" }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(section_text("現在有効な注意事項")).to include(active_term.title)
      expect(page_text).to include("絞り込み中:")
      expect(consent_history_rows.map { _1[1] }).to contain_exactly("Project Review Terms")
      expect(page_text).not_to include("Other User Project Review Terms")
    end

    get consents_path, params: { q: "Consent Document" }

    expect(response).to have_http_status(:ok)
    expect(consent_history_rows.map { _1[1] }).to contain_exactly("Document Reading Terms")
  end

  it "filters by valid consent_scope and ignores unsupported scope values safely" do
    project_term = create(:consent_term, title: "Project Terms", version_label: "v-project", consent_scope: :project, active: false)
    download_term = create(:consent_term, title: "Download Terms", version_label: "v-download", consent_scope: :download, active: false)

    create(:user_consent, user:, consent_term: project_term, target: project, consent_term_version_label: "v-project")
    create(:user_consent, user:, consent_term: download_term, target: file, consent_term_version_label: "v-download")

    sign_in_as(user)

    get consents_path, params: { consent_scope: "download" }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("種別「ダウンロード」")
      expect(consent_history_rows.map { _1[1] }).to contain_exactly("Download Terms")
      expect(page_text).not_to include("Project Terms")
    end

    get consents_path, params: { consent_scope: "unexpected" }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).not_to include("種別「unexpected」")
      expect(consent_history_rows.map { _1[1] }).to contain_exactly("Project Terms", "Download Terms")
    end
  end

  it "separates filtered empty state from a user with no consent history" do
    active_term = create(:consent_term, title: "Active Only Terms", body: "Active body", version_label: "v-active", consent_scope: :global)
    history_term = create(:consent_term, title: "Existing History Terms", version_label: "v-history", consent_scope: :project, active: false)
    create(:user_consent, user:, consent_term: history_term, target: project, consent_term_version_label: "v-history")

    sign_in_as(user)
    get consents_path, params: { q: "not-found" }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(section_text("現在有効な注意事項")).to include(active_term.title)
      expect(section_text("自分の同意履歴")).to include("絞り込み条件に一致する同意履歴はありません")
      expect(section_text("自分の同意履歴")).not_to include("まだ同意履歴はありません")
    end
  end
end
