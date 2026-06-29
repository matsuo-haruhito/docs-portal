require "rails_helper"

RSpec.describe "Consent history target filter", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:other_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "CONSENT", name: "Consent Project") }
  let(:document) { create(:document, project:, title: "Consent Document", slug: "consent-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "history.pdf") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def consent_history_titles
    history = parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == "自分の同意履歴" }
    history.css("tbody tr").map { |row| row.css("td")[1].text.squish }
  end

  def create_history(title:, scope:, target:, consented_at: Time.zone.parse("2026-01-01 09:00"), actor: user)
    term = create(:consent_term, title:, consent_scope: scope, version_label: "v-#{title.parameterize}", active: false)
    create(:user_consent, user: actor, consent_term: term, target:, consent_term_version_label: term.version_label, consented_at:)
  end

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :download)
    document.update!(latest_version: version)
  end

  it "filters the current user's consent history by target type" do
    create_history(title: "Global Terms", scope: :global, target: nil, consented_at: Time.zone.parse("2026-01-05 09:00"))
    create_history(title: "Project Terms", scope: :project, target: project, consented_at: Time.zone.parse("2026-01-04 09:00"))
    create_history(title: "Document Terms", scope: :document, target: document, consented_at: Time.zone.parse("2026-01-03 09:00"))
    create_history(title: "File Terms", scope: :download, target: file, consented_at: Time.zone.parse("2026-01-02 09:00"))
    create_history(title: "Version Terms", scope: :download, target: version, consented_at: Time.zone.parse("2026-01-01 09:00"))
    create_history(title: "Other User Project Terms", scope: :project, target: project, actor: other_user, consented_at: Time.zone.parse("2026-01-06 09:00"))

    sign_in_as(user)

    get consents_path(target_type: "global")
    expect(response).to have_http_status(:ok)
    expect(consent_history_titles).to eq(["Global Terms"])
    expect(page_text).to include("対象種別「全体」")
    expect(page_text).not_to include("Other User Project Terms")

    get consents_path(target_type: "Project")
    expect(response).to have_http_status(:ok)
    expect(consent_history_titles).to eq(["Project Terms"])
    expect(page_text).to include("対象種別「案件」")

    get consents_path(target_type: "DocumentFile")
    expect(response).to have_http_status(:ok)
    expect(consent_history_titles).to eq(["File Terms"])
    expect(page_text).to include("対象種別「ファイル」")
  end

  it "combines consent scope and target type without filtering the active terms section" do
    active_term = create(:consent_term, title: "Active Project Terms", body: "Active body", version_label: "v-active", consent_scope: :project)
    create_history(title: "Global Download Terms", scope: :download, target: nil, consented_at: Time.zone.parse("2026-01-04 09:00"))
    create_history(title: "File Download Terms", scope: :download, target: file, consented_at: Time.zone.parse("2026-01-03 09:00"))
    create_history(title: "Document Project Terms", scope: :project, target: document, consented_at: Time.zone.parse("2026-01-02 09:00"))

    sign_in_as(user)
    get consents_path(consent_scope: "download", target_type: "DocumentFile")

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(consent_history_titles).to eq(["File Download Terms"])
      expect(page_text).to include("種別「ダウンロード」")
      expect(page_text).to include("対象種別「ファイル」")
      expect(page_text).to include("Active Project Terms")
      expect(page_text).to include("現在有効な注意事項")
    end

    expect(active_term).to be_persisted
  end

  it "ignores unsupported target type values without widening beyond the current user" do
    create_history(title: "Current User Global Terms", scope: :global, target: nil, consented_at: Time.zone.parse("2026-01-03 09:00"))
    create_history(title: "Current User Project Terms", scope: :project, target: project, consented_at: Time.zone.parse("2026-01-02 09:00"))
    create_history(title: "Other User Global Terms", scope: :global, target: nil, actor: other_user, consented_at: Time.zone.parse("2026-01-04 09:00"))

    sign_in_as(user)
    get consents_path(target_type: "Organization")

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(consent_history_titles).to eq(["Current User Global Terms", "Current User Project Terms"])
      expect(page_text).not_to include("対象種別「Organization」")
      expect(page_text).not_to include("Other User Global Terms")
    end
  end
end
