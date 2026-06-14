require "rails_helper"

RSpec.describe "Document catalog empty state cues", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "CATEMPTY", name: "Catalog Empty Project") }
  let(:external_user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def main_text
    parsed_html.at("main")&.text.to_s.squish
  end

  def empty_state_text
    parsed_html.css("section.document-catalog-empty-state").map { |section| section.text.squish }.join("\n")
  end

  before do
    create(:project_membership, project:, user: external_user)
    sign_in_as(external_user)
  end

  it "keeps active filter labels and reset action next to a filtered empty state" do
    create(:document_catalog, project:, name: "Customer Pack", description: "Shared onboarding", audience_type: :customer, visibility_policy: :restricted_external)

    get project_document_catalogs_path(
      project,
      q: "needle",
      audience_type: "customer",
      visibility_policy: "restricted_external"
    )

    expect(response).to have_http_status(:ok)
    expect(empty_state_text).to include("条件に一致する文書カタログはありません。")
    expect(empty_state_text).to include("現在の絞り込みは次の条件です。")
    expect(empty_state_text).to include("名称・説明: needle")
    expect(empty_state_text).to include("対象: 顧客向け")
    expect(empty_state_text).to include("公開範囲: 限定公開")
    expect(parsed_html.css("section.document-catalog-empty-state a").map { |link| link.text.squish }).to include("絞り込み解除")
  end

  it "explains an unfiltered empty state without exposing hidden catalog names" do
    create(:document_catalog, project:, name: "Internal Pack", visibility_policy: :internal_only)

    get project_document_catalogs_path(project)

    expect(response).to have_http_status(:ok)
    expect(empty_state_text).to include("利用可能な文書カタログはありません。")
    expect(empty_state_text).to include("未作成、権限外、または非公開のカタログはここには表示されません。")
    expect(main_text).not_to include("条件に一致する文書カタログはありません。")
    expect(main_text).not_to include("Internal Pack")
  end

  it "does not treat unsupported enum params as active filters" do
    create(:document_catalog, project:, name: "Customer Pack", audience_type: :customer, visibility_policy: :restricted_external)

    get project_document_catalogs_path(project, audience_type: "unknown", visibility_policy: "archived")

    expect(response).to have_http_status(:ok)
    expect(main_text).to include("Customer Pack")
    expect(main_text).not_to include("現在の絞り込み")
    expect(main_text).not_to include("条件に一致する文書カタログはありません。")
    expect(main_text).not_to include("unknown")
    expect(main_text).not_to include("archived")
  end
end
