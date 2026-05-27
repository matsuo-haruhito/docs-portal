require "rails_helper"

RSpec.describe "Admin document sets index", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Alpha Project") }
  let!(:document_set) do
    create(
      :document_set,
      project: project,
      name: "Release Bundle",
      set_type: :delivery,
      visibility_policy: :restricted_external
    )
  end
  let!(:document) { create(:document, project: project) }
  let!(:document_set_item) { create(:document_set_item, document_set: document_set, document: document) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "renders the table preferences editor and stable column keys" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書セット一覧の表示設定")

    headers = parsed_html.css("thead th[data-rails-table-preferences-column-key]")

    expect(headers.map { |header| header["data-rails-table-preferences-column-key"] }).to eq(
      %w[project name set_type visibility_policy documents_count actions]
    )

    row = parsed_html.css("tbody tr").find { |candidate| candidate.text.include?("Release Bundle") }

    expect(row).to be_present
    expect(row.at_css('td[data-rails-table-preferences-column-key="project"]').text.squish).to include("Alpha Project")
    expect(row.at_css('td[data-rails-table-preferences-column-key="documents_count"]').text.squish).to include("1")

    actions_cell = row.at_css('td[data-rails-table-preferences-column-key="actions"]')
    action_targets = actions_cell.css("a[href], form[action]").map { |node| node["href"] || node["action"] }

    expect(actions_cell.text.squish).to include("編集", "削除")
    expect(action_targets).to include(edit_admin_document_set_path(document_set), admin_document_set_path(document_set))
  end
end
