require "rails_helper"

RSpec.describe "Admin document set version usage cue", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Version Cue Project") }
  let(:document_a) { create(:document, project:, title: "固定対象", slug: "fixed-target") }
  let(:document_b) { create(:document, project:, title: "最新版対象", slug: "latest-target") }
  let(:version_a1) { create(:document_version, document: document_a, version_label: "v1.0.0") }
  let!(:fixed_set) do
    create(
      :document_set,
      project:,
      name: "固定版ありセット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end
  let!(:latest_set) do
    create(
      :document_set,
      project:,
      name: "最新版のみセット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 2
    )
  end
  let!(:empty_set) do
    create(
      :document_set,
      project:,
      name: "未設定セット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 3
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def document_set_row(name)
    parsed_html.css("table tbody tr").find do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="name"]))&.text&.squish == name
    end
  end

  def documents_count_cell_for(name)
    document_set_row(name).at_css(%(td[data-rails-table-preferences-column-key="documents_count"]))
  end

  before do
    create(:document_set_item, document_set: fixed_set, document: document_a, document_version: version_a1, sort_order: 1)
    create(:document_set_item, document_set: fixed_set, document: document_b, sort_order: 2)
    create(:document_set_item, document_set: latest_set, document: document_b, sort_order: 1)
  end

  it "shows fixed version and latest-only cues inside the existing documents count column" do
    sign_in_as(admin)

    get admin_document_sets_path(set_type: "delivery")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("種別: 送付用")

    expect(documents_count_cell_for("固定版ありセット").text.squish).to eq("2 固定版あり（1件）")
    expect(documents_count_cell_for("最新版のみセット").text.squish).to eq("1 最新版のみ")
    expect(documents_count_cell_for("未設定セット").text.squish).to eq("0 文書なし")
    expect(parsed_html.css(%(td[data-rails-table-preferences-column-key="documents_count"] .badge)).map { _1.text.squish }).to include(
      "固定版あり（1件)",
      "最新版のみ",
      "文書なし"
    ).or include(
      "固定版あり（1件）",
      "最新版のみ",
      "文書なし"
    )
    expect(response.body).to include('data-rails-table-preferences-column-key="documents_count"')
  end
end
