require "rails_helper"
require "fileutils"

RSpec.describe "Consents", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "CONSENT", name: "Consent Project") }
  let(:document) { create(:document, project:, title: "Consent Document", slug: "consent-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) do
    create(
      :document_file,
      document_version: version,
      file_name: "manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/consents/manual.pdf",
      file_size: 8,
      scan_status: :scan_clean
    )
  end
  let(:unsafe_return_to_values) do
    [
      "",
      "//example.com/outside",
      "https://example.com/outside",
      "http://example.com/outside",
      "javascript:alert(1)",
      "evil/path",
      "/projects#section",
      "/projects/\u0000outside"
    ]
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_hrefs(text)
    parsed_html.css("a").filter_map do |link|
      link["href"] if link.text.squish == text
    end
  end

  def hidden_return_to_values
    parsed_html.css('input[name="return_to"]').map { _1["value"] }
  end

  def section_text(heading)
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == heading }&.text&.squish
  end

  def consent_history_titles
    history = parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == "自分の同意履歴" }
    history.css("tbody tr").map { |row| row.css("td")[1].text.squish }
  end

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :download)
    document.update!(latest_version: version)
  end

  it "redirects project access to the consent screen until agreed" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    get project_path(project)

    expect(response).to redirect_to(new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: :first_view, return_to: project_path(project)))

    follow_redirect!
    expect(page_text).to include("Project Terms")
    expect(page_text).to include("対象:")
    expect(page_text).to include("案件 / Consent Project")
    expect(page_text).to include("種別:")
    expect(page_text).to include("案件")

    expect do
      post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: project_path(project) }
    end.to change(UserConsent, :count).by(1)

    expect(response).to redirect_to(project_path(project))

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Consent Document")
  end

  it "does not create duplicate consent records when the same missing term is posted twice" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    params = { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: project_path(project) }

    expect do
      post consents_path, params:
    end.to change(UserConsent, :count).by(1)

    expect do
      post consents_path, params:
    end.not_to change(UserConsent, :count)

    expect(UserConsent.where(user:, consent_term: term, target: project)).to contain_exactly(UserConsent.last)
  end

  it "uses the current return_to for the back link when it is a path-only internal URL" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    return_to = "#{document_file_path(file)}?source_path=manuals"
    get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

    expect(response).to have_http_status(:ok)
    expect(link_hrefs("同意せず戻る")).to include(return_to)
    expect(hidden_return_to_values).to include(return_to)
  end

  it "shows missing term count and return guidance without changing the safe return_to" do
    project_term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    second_project_term = create(:consent_term, title: "Second Project Terms", consent_scope: :project, version_label: "v2")
    create(:project_consent_setting, project:, consent_term: project_term, required_on: :first_access)
    create(:project_consent_setting, project:, consent_term: second_project_term, required_on: :first_access)

    sign_in_as(user)

    return_to = "#{document_file_path(file)}?source_path=manuals"
    get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("確認が必要な注意事項が2件あります")
      expect(page_text).to include("文面ごとに対象・種別・版を確認してください")
      expect(page_text).to include("同意後は、安全に戻れる画面がある場合はその画面へ進みます。ない場合は案件一覧へ戻ります")
      expect(page_text).to include("同意しない場合も、安全に戻れる画面がある場合はその画面へ戻ります。ない場合は案件一覧へ戻ります")
      expect(page_text).to include("Project Terms", "Second Project Terms")
      expect(link_hrefs("同意せず戻る")).to include(return_to)
      expect(hidden_return_to_values).to include(return_to)
    end
  end

  it "falls back to projects_path for the back link when return_to is unsafe" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    unsafe_return_to_values.each do |return_to|
      get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

      expect(response).to have_http_status(:ok)
      expect(link_hrefs("同意せず戻る")).to include(projects_path)
      expect(hidden_return_to_values).to include(projects_path)
      expect(hidden_return_to_values).not_to include(return_to) if return_to.present?
    end
  end

  it "redirects immediately using the safe return_to rule when no terms are missing" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)
    create(:user_consent, user:, consent_term: term, target: project, consent_term_version_label: "v1")

    sign_in_as(user)

    safe_return_to = "#{project_documents_path(project)}?q=manual"
    get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: safe_return_to)
    expect(response).to redirect_to(safe_return_to)

    unsafe_return_to_values.each do |return_to|
      get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

      expect(response).to redirect_to(projects_path)
    end
  end

  it "falls back to projects_path after consent when return_to is unsafe" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    unsafe_return_to_values.each do |return_to|
      post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: }

      expect(response).to redirect_to(projects_path)
    end
  end

  it "redirects file downloads to download consent and does not log before consent" do
    term = create(:consent_term, title: "Download Terms", consent_scope: :download, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :download)
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.binwrite(file.absolute_path, "%PDF-1.4")

    sign_in_as(user)

    expect do
      get document_file_path(file)
    end.not_to change(AccessLog, :count)

    expect(response).to redirect_to(new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: :download, return_to: document_file_path(file)))

    post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "download", return_to: document_file_path(file) }

    expect(response).to redirect_to(document_file_path(file))

    expect do
      get document_file_path(file)
    end.to change(AccessLog.where(action_type: :download), :count).by(1)

    expect(response).to have_http_status(:ok)
  ensure
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "consents"))
  end

  it "shows empty state copy as a non-error state when active terms and history are absent" do
    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(section_text("現在有効な注意事項")).to include("ここには今提示されている active な文面だけを表示します")
      expect(section_text("現在有効な注意事項")).to include("今提示する文面がない状態で、エラーや権限不足ではありません")
      expect(section_text("自分の同意履歴")).to include("ここには自分が同意した文面と版の記録を表示します")
      expect(section_text("自分の同意履歴")).to include("自分の同意記録が0件の状態で、利用不可や権限不足を示すものではありません")
    end
  end

  it "shows count and body cues for multiple active terms without changing history meaning" do
    create(
      :consent_term,
      title: "Project Long Terms",
      body: "案件利用時に確認する長めの注意事項です。文面ごとに本文を読み分けます。",
      version_label: "v-project-2",
      consent_scope: :project
    )
    create(
      :consent_term,
      title: "Download Long Terms",
      body: "ダウンロード前に確認する長めの注意事項です。履歴ではなく現在提示中の本文です。",
      version_label: "v-download-3",
      consent_scope: :download
    )

    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      active_section = section_text("現在有効な注意事項")
      history_section = section_text("自分の同意履歴")

      expect(active_section).to include("現在有効な注意事項が2件あります")
      expect(active_section).to include("各文面の種別・版を確認し、本文は文面ごとに読み分けてください")
      expect(active_section).to include("Project Long Terms", "案件", "v-project-2")
      expect(active_section).to include("Download Long Terms", "ダウンロード", "v-download-3")
      expect(active_section.scan("この文面の本文").size).to eq(2)
      expect(active_section).to include("案件利用時に確認する長めの注意事項です")
      expect(active_section).to include("ダウンロード前に確認する長めの注意事項です")
      expect(history_section).to include("自分が同意した文面と版の記録")
      expect(history_section).to include("自分の同意記録が0件の状態")
    end
  end

  it "shows only the current user's consent history in consented_at and id descending order" do
    other_user = create(:user, :external, company:)
    active_term = create(:consent_term, title: "Current Active Terms", body: "Visible active body", version_label: "v-active", consent_scope: :project)
    older_term = create(:consent_term, title: "Older History Terms", body: "Older history body", version_label: "v-old", consent_scope: :download)
    same_time_first_term = create(:consent_term, title: "Same Timestamp First", body: "First same-time body", version_label: "v-same-1", consent_scope: :global)
    same_time_second_term = create(:consent_term, title: "Same Timestamp Second", body: "Second same-time body", version_label: "v-same-2", consent_scope: :global)
    inactive_term = create(:consent_term, title: "Inactive Hidden Terms", body: "Inactive hidden body", version_label: "v-hidden", active: false)
    other_history_term = create(:consent_term, title: "Other User History Terms", body: "Other user body", version_label: "v-other", active: false)
    same_time = Time.zone.parse("2026-01-03 09:00")

    create(:user_consent, user:, consent_term: older_term, target: project, consent_term_version_label: "v-old", consented_at: Time.zone.parse("2026-01-01 09:00"))
    create(:user_consent, user:, consent_term: same_time_first_term, target: nil, consent_term_version_label: "v-same-1", consented_at: same_time)
    create(:user_consent, user:, consent_term: same_time_second_term, target: document, consent_term_version_label: "v-same-2", consented_at: same_time)
    create(:user_consent, user: other_user, consent_term: other_history_term, target: project, consent_term_version_label: "v-other", consented_at: Time.zone.parse("2026-01-04 09:00"))

    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(section_text("現在有効な注意事項")).to include("Current Active Terms")
      expect(section_text("現在有効な注意事項")).to include("Visible active body")
      expect(section_text("現在有効な注意事項")).to include("今提示されている active な文面だけ")
      expect(section_text("自分の同意履歴")).to include("自分が同意した文面と版の記録")
      expect(page_text).not_to include("Inactive Hidden Terms")
      expect(page_text).not_to include("Inactive hidden body")
      expect(page_text).not_to include("Other User History Terms")
      expect(page_text).not_to include("Other user body")
      expect(consent_history_titles).to eq([
        "Same Timestamp Second",
        "Same Timestamp First",
        "Older History Terms"
      ])
    end

    expect(active_term).to be_persisted
    expect(inactive_term).to be_persisted
  end

  it "shows active terms and the user's consent history with localized target and scope labels" do
    file = create(:document_file, document_version: version, file_name: "history.pdf")
    term = create(:consent_term, title: "Visible Terms", body: "Handle carefully", version_label: "v1", consent_scope: :download)

    create(:user_consent, user:, consent_term: term, target: nil, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: project, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: document, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: file, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: version, consent_term_version_label: "v1")

    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Visible Terms")
    expect(page_text).to include("Handle carefully")
    expect(page_text).to include("会社間契約や法務承認の代替ではありません")
    expect(page_text).to include("対象が「全体」の行は案件や文書にひも付かない同意です")
    expect(page_text).to include("案件 / 文書 / ファイル / 文書版が出ている行は、その対象に対する同意です")
    expect(page_text).to include("種別")
    expect(page_text).to include("ダウンロード")
    expect(page_text).to include("v1")
    expect(page_text).to include("全体")
    expect(page_text).to include("案件 / Consent Project")
    expect(page_text).to include("文書 / Consent Document")
    expect(page_text).to include("ファイル / history.pdf")
    expect(page_text).to include("文書版 / v1.0.0")
    expect(page_text).not_to include("Project / Consent Project")
    expect(page_text).not_to include("Document / Consent Document")
    expect(page_text).not_to include("DocumentFile / history.pdf")
    expect(page_text).not_to include("DocumentVersion / v1.0.0")
    expect(page_text).not_to include(">download<")
  end
end
