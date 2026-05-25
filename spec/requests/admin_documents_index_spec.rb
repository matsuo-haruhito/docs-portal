require "rails_helper"

RSpec.describe "Admin documents index", type: :request do
  let(:admin) { create(:user, :admin, name: "管理者") }
  let(:project) { create(:project, code: "ALPHA", name: "Alpha Project") }
  let!(:active_document) do
    create(
      :document,
      project: project,
      title: "運用手順",
      slug: "operations",
      category: :manual,
      document_kind: :markdown,
      visibility_policy: :internal_only,
      retention_until: Date.new(2026, 12, 31)
    )
  end
  let!(:archived_document) do
    create(
      :document,
      project: project,
      title: "旧仕様",
      slug: "legacy-spec",
      category: :spec,
      document_kind: :pdf,
      visibility_policy: :restricted_external,
      discard_candidate_at: Date.new(2027, 1, 15)
    ).tap do |document|
      document.archive!(actor: admin)
    end
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "renders the table preferences editor, stable column keys, and existing actions" do
    sign_in_as(admin)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書マスタ一覧の表示設定")

    editor = parsed_html.at_css(".rails-table-preferences-editor[data-controller='rails-table-preferences']")

    expect(editor).to be_present
    expect(editor["data-rails-table-preferences-table-key-value"]).to eq("admin_documents")

    header_keys = parsed_html.css("thead th[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end

    expect(header_keys).to eq(%w[project title slug category document_kind visibility_policy status retention_until discard_candidate_at actions])

    active_row = parsed_html.css("tbody tr").find { |row| row.text.include?("運用手順") }
    archived_row = parsed_html.css("tbody tr").find { |row| row.text.include?("旧仕様") }

    expect(active_row).to be_present
    expect(archived_row).to be_present

    expect(active_row.at_css('td[data-rails-table-preferences-column-key="project"]').text).to include("Alpha Project")
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="status"]').text).to include("有効")
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="retention_until"]').text).to include("2026")

    active_actions = active_row.at_css('td[data-rails-table-preferences-column-key="actions"]')

    expect(active_actions.to_html).to include(project_document_path(project, active_document.slug))
    expect(active_actions.to_html).to include(edit_admin_document_path(active_document))
    expect(active_actions.to_html).to include(archive_admin_document_path(active_document))
    expect(active_actions.to_html).to include(admin_document_path(active_document))

    archived_status = archived_row.at_css('td[data-rails-table-preferences-column-key="status"]')
    archived_actions = archived_row.at_css('td[data-rails-table-preferences-column-key="actions"]')

    expect(archived_status.text).to include("アーカイブ済み")
    expect(archived_status.text).to include("実行者: 管理者")
    expect(archived_actions.to_html).to include(edit_admin_document_path(archived_document))
    expect(archived_actions.to_html).to include(restore_admin_document_path(archived_document))
    expect(archived_actions.to_html).to include(admin_document_path(archived_document))
  end
end
