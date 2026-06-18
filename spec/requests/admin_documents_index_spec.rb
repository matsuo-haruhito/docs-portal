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

  def page_text
    parsed_html.text.squish
  end

  def form_clear_filter_targets
    parsed_html.css("form.document-filter-form .form-actions a[href]").select do |node|
      node.text.squish == "条件をクリア"
    end.map { |node| node["href"] }
  end

  def empty_state_clear_filter_targets
    parsed_html.css(".document-filter-empty-state a[href]").select do |node|
      node.text.squish == "条件をクリア"
    end.map { |node| node["href"] }
  end

  it "renders the table preferences editor, stable column keys, and existing actions" do
    sign_in_as(admin)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書マスタ一覧の表示設定")
    expect(page_text).to include("文書マスタ一覧の表示設定と検索条件は、この一覧の列表示・列幅・表示件数にだけ適用されます")
    expect(page_text).to include("文書詳細の左ペインにある文書ツリーの「表示中」や展開状態とは別の文脈です")

    editor = parsed_html.at_css(".rails-table-preferences-editor[data-controller='rails-table-preferences']")

    expect(editor).to be_present
    expect(editor["data-rails-table-preferences-table-key-value"]).to eq("admin_documents")
    expect(editor["data-rails-table-preferences-collection-url-value"]).to end_with("/rails_table_preferences/preferences/admin_documents")
    expect(editor["data-rails-table-preferences-url-value"]).to end_with("/rails_table_preferences/preferences/admin_documents/default")

    header_keys = parsed_html.css("thead th[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end

    expect(header_keys).to eq(%w[project title slug category document_kind visibility_policy status latest_version legacy_versions retention_until discard_candidate_at actions])

    active_row = parsed_html.css("tbody tr").find { |row| row.text.include?("運用手順") }
    archived_row = parsed_html.css("tbody tr").find { |row| row.text.include?("旧仕様") }

    expect(active_row).to be_present
    expect(archived_row).to be_present

    expect(active_row.at_css('td[data-rails-table-preferences-column-key="project"]').text).to include("Alpha Project")
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="title"]').to_html).to include(project_document_path(project, active_document.slug))
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="status"]').text).to include("有効")
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="latest_version"]').text).to include("最新版なし")
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="legacy_versions"]').text).to include("候補なし")
    expect(active_row.at_css('td[data-rails-table-preferences-column-key="retention_until"]').text).to include("2026")

    active_actions = active_row.at_css('td[data-rails-table-preferences-column-key="actions"]')

    expect(active_actions.to_html).to include(edit_admin_document_path(active_document.public_id))
    expect(active_actions.to_html).to include(archive_admin_document_path(active_document.public_id))
    expect(active_actions.to_html).to include(admin_document_path(active_document.public_id))

    archived_status = archived_row.at_css('td[data-rails-table-preferences-column-key="status"]')
    archived_actions = archived_row.at_css('td[data-rails-table-preferences-column-key="actions"]')

    expect(archived_status.text).to include("アーカイブ済み")
    expect(archived_status.text).to include("実行者: 管理者")
    expect(archived_actions.to_html).to include(edit_admin_document_path(archived_document.public_id))
    expect(archived_actions.to_html).to include(restore_admin_document_path(archived_document.public_id))
    expect(archived_actions.to_html).to include(admin_document_path(archived_document.public_id))
  end

  it "shows the document clear filter action only when filters are active" do
    sign_in_as(admin)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("条件をクリア")
    expect(form_clear_filter_targets).to be_empty

    get admin_documents_path, params: { q: "ALPHA" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("有効な条件:", "キーワード: ALPHA")
    expect(form_clear_filter_targets).to eq([admin_documents_path])
  end

  it "keeps a clear filter path near empty filtered document results" do
    sign_in_as(admin)

    get admin_documents_path, params: { q: "no matching document" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 0件")
    expect(page_text).to include("条件に一致する文書はありません")
    expect(page_text).to include("文書マスタ全体に戻れます")
    expect(form_clear_filter_targets).to eq([admin_documents_path])
    expect(empty_state_clear_filter_targets).to eq([admin_documents_path])
  end
end
