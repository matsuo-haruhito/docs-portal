require "rails_helper"

RSpec.describe "Project AI contexts", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, body:, visibility_policy: :restricted_external, access_level: :view, project: self.project)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md", search_body_text: body)
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level:) unless visibility_policy == :internal_only
    document
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def ai_context_link_href(label)
    parsed_html.css("a").find { _1.text.squish == label }["href"]
  end

  def document_choice_labels
    parsed_html.css("fieldset.filter-fieldset label.check-field").map { _1.text.squish }
  end

  it "shows project AI context html and exports json/markdown for visible documents only" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_ai_context_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("AI向けコンテキスト")
    expect(response.body).to include("現在の出力モード:")
    expect(response.body).to include("概要中心")
    expect(response.body).to include("mode: compact")
    expect(response.body).to include("概要中心: summary と文書メタデータ中心")
    expect(response.body).to include("本文込み: 概要中心の内容に加えて本文テキストを含め")
    expect(response.body).to include("JSON / Markdown は現在の出力モード")
    expect(response.body).to include("対象文書を絞り込む")
    expect(page_text).to include("現在は閲覧可能な文書全体（1件）を出力対象にしています。")
    expect(page_text).to include("個別に絞り込む場合は、対象にしたい文書だけを残して preview してください。")
    expect(page_text).to include("出力候補（表示中1 / 全1件）")
    expect(page_text).to include("文書名 / slug で検索")
    expect(page_text).to include("検索後も、明示選択済みの文書は候補に残します。")
    expect(response.body).to include("含まれる文書（出力対象）")
    expect(response.body).to include("除外された文書（権限・公開状態の確認）")
    expect(response.body).to include("Visible Manual")
    expect(response.body).to include("Internal Note")

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([visible.public_id])

    get project_ai_context_path(project, format: :md, mode: :full)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("# Project: AI Context Project")
    expect(response.body).to include("Visible body text.")
    expect(response.body).not_to include("Secret body text.")
  end

  it "exports document file metadata without binary, signed urls, or hidden document leakage" do
    downloadable = create_exportable_document(
      title: "Downloadable Manual",
      slug: "downloadable",
      body: "Downloadable body text.",
      access_level: :download
    )
    view_only = create_exportable_document(title: "View Only Manual", slug: "view-only", body: "View only body text.")
    internal = create_exportable_document(title: "Internal Attachment Note", slug: "internal-attachment", body: "Secret body text.", visibility_policy: :internal_only)
    downloadable_file = create(
      :document_file,
      document_version: downloadable.latest_version,
      file_name: "requirements.pdf",
      content_type: "application/pdf",
      file_size: 12_345,
      scan_status: :scan_clean,
      storage_key: "spec/ai-context/requirements.pdf"
    )
    view_only_file = create(
      :document_file,
      document_version: view_only.latest_version,
      file_name: "diagram.png",
      content_type: "image/png",
      file_size: 2_048,
      scan_status: :scan_clean,
      storage_key: "spec/ai-context/diagram.png"
    )
    create(
      :document_file,
      document_version: internal.latest_version,
      file_name: "secret-plan.pdf",
      content_type: "application/pdf",
      file_size: 99,
      scan_status: :scan_clean,
      storage_key: "spec/ai-context/secret-plan.pdf"
    )

    sign_in_as(external_user)

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    downloadable_json = json.fetch("documents").find { _1.fetch("public_id") == downloadable.public_id }
    view_only_json = json.fetch("documents").find { _1.fetch("public_id") == view_only.public_id }
    expect(downloadable_json.fetch("document_files")).to contain_exactly(
      a_hash_including(
        "public_id" => downloadable_file.public_id,
        "file_name" => "requirements.pdf",
        "content_type" => "application/pdf",
        "file_size" => 12_345,
        "scan_status" => "scan_clean",
        "downloadable" => true
      )
    )
    expect(view_only_json.fetch("document_files")).to contain_exactly(
      a_hash_including(
        "public_id" => view_only_file.public_id,
        "file_name" => "diagram.png",
        "content_type" => "image/png",
        "file_size" => 2_048,
        "scan_status" => "scan_clean",
        "downloadable" => false
      )
    )
    expect(response.body).not_to include("secret-plan.pdf", "spec/ai-context", "signed_id", "download_url")

    get project_ai_context_path(project, format: :md, mode: :full)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("Attachments:")
    expect(response.body).to include("- requirements.pdf (content_type: application/pdf, size: 12345, scan_status: scan_clean, downloadable: true)")
    expect(response.body).to include("- diagram.png (content_type: image/png, size: 2048, scan_status: scan_clean, downloadable: false)")
    expect(response.body).not_to include("secret-plan.pdf", "spec/ai-context", "signed_id", "download_url")
  end

  it "returns bad request for unsupported modes before exporting or logging access" do
    sign_in_as(external_user)

    expect do
      get project_ai_context_path(project, mode: "verbose")
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("unsupported mode")

      get project_ai_context_path(project, format: :json, mode: "verbose")
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "unsupported mode")

      get project_ai_context_path(project, format: :md, mode: "verbose")
      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq("text/markdown")
      expect(response.body).to include("unsupported mode")
    end.not_to change(AccessLog.where(target_type: "ai_context"), :count)
  end

  it "keeps selected document ids across preview and scoped exports" do
    selected = create_exportable_document(title: "Selected Manual", slug: "selected", body: "Selected body text.")
    other_visible = create_exportable_document(title: "Other Manual", slug: "other", body: "Other body text.")
    internal = create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)
    other_project = create(:project, code: "OTHERCTX", name: "Other Context Project")
    outside_project_document = create_exportable_document(
      title: "Outside Project Manual",
      slug: "outside-project",
      body: "Outside project body text.",
      project: other_project
    )
    missing_document_id = Document.maximum(:id) + 100

    sign_in_as(external_user)

    get project_ai_context_path(project, mode: :full, document_ids: [selected.id, internal.id, outside_project_document.id, missing_document_id])
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("出力対象:1 件")
    expect(page_text).to include("現在の出力モード: 本文込み")
    expect(page_text).to include("mode: full")
    expect(page_text).to include("明示選択: 4件 / 案件内候補: 2件 / 出力対象: 1件")
    expect(page_text).to include("選択文書のうち閲覧可能な文書だけが preview / 出力に含まれます。案件外または存在しないIDは候補外として数だけ表示します。")
    expect(page_text).to include("選択済み確認: 1件の閲覧可能な選択文書を保持しています。")
    expect(page_text).to include("候補外として無視された選択ID: 2件。案件外または存在しないIDは、文書名やIDを表示せず集計だけで示します。")
    expect(page_text).to include("出力候補（4 / 2件選択中、表示中2件）")
    expect(page_text).to include("Selected Manual", "Other Manual", "Internal Note")
    expect(page_text).not_to include("Outside Project Manual")
    expect(ai_context_link_href("概要中心に切り替え")).to include("document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("本文込みに切り替え")).to include("document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("JSON を出力")).to include("mode=full", "document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("Markdown を出力")).to include("mode=full", "document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("選択済みだけ表示")).to include("mode=full", "document_ids%5B%5D=#{selected.id}", "candidate_view=selected")

    get project_ai_context_path(project, format: :json, mode: :compact, document_ids: [selected.id, internal.id, outside_project_document.id, missing_document_id])
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([selected.public_id])
    expect(response.body).not_to include("Outside project body text.", "Secret body text.")

    get project_ai_context_path(project, format: :md, mode: :full, document_ids: [selected.id])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Selected body text.")
    expect(response.body).not_to include("Other body text.", "Secret body text.")

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(2)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to contain_exactly(selected.public_id, other_visible.public_id)

    get project_ai_context_path(project, mode: :full, document_ids: [internal.id], candidate_view: :selected)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("候補表示: 選択済みのみ / 表示中: 0件 / 選択済み候補: 0件 / 閲覧可能: 2件")
    expect(page_text).to include("選択済み表示で確認できる閲覧可能な文書はありません。")
    expect(page_text).to include("検索候補へ戻るか、すべての文書に戻して対象範囲を確認してください。")
    expect(ai_context_link_href("検索候補へ戻る")).to include("mode=full", "document_ids%5B%5D=#{internal.id}")
    expect(ai_context_link_href("検索候補へ戻る")).not_to include("candidate_view=selected")
    expect(ai_context_link_href("すべての文書に戻す")).to include("mode=full")
  end

  it "keeps document_q as a candidate filter until document_ids are submitted" do
    matching = create_exportable_document(title: "Setup Guide", slug: "setup-guide", body: "Setup guide body text.")
    non_matching = create_exportable_document(title: "Operations Manual", slug: "operations", body: "Operations body text.")

    sign_in_as(external_user)

    get project_ai_context_path(project, document_q: "setup")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件: setup")
    expect(page_text).to include("出力候補（検索結果1 / 閲覧可能2件、表示中1件）")
    expect(page_text).to include("検索は checkbox 候補の絞り込みで、JSON / Markdown 出力は「選択した文書でpreview」を押すまで現在の対象範囲を維持します。")
    expect(document_choice_labels).to contain_exactly(a_string_including("Setup Guide"))

    get project_ai_context_path(project, format: :json, mode: :compact, document_q: "setup")
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(2)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to contain_exactly(matching.public_id, non_matching.public_id)

    get project_ai_context_path(project, format: :md, mode: :full, document_q: "setup")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Setup guide body text.", "Operations body text.")
  end

  it "deduplicates selected ids and falls back from selected view when no valid ids are submitted" do
    selected = create_exportable_document(title: "Selected Manual", slug: "selected", body: "Selected body text.")
    create_exportable_document(title: "Other Manual", slug: "other", body: "Other body text.")
    internal = create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)
    other_project = create(:project, code: "OTHERCTX", name: "Other Context Project")
    outside_project_document = create_exportable_document(
      title: "Outside Project Manual",
      slug: "outside-project",
      body: "Outside project body text.",
      project: other_project
    )
    missing_document_id = Document.maximum(:id) + 100
    mixed_document_ids = [selected.id, selected.id.to_s, internal.id, outside_project_document.id, missing_document_id, "0", "-1", "not-a-number"]

    sign_in_as(external_user)

    get project_ai_context_path(project, candidate_view: :selected, document_ids: mixed_document_ids)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("明示選択: 4件 / 案件内候補: 2件 / 出力対象: 1件")
    expect(page_text).to include("候補表示: 選択済みのみ / 表示中: 1件 / 選択済み候補: 1件 / 閲覧可能: 2件")
    expect(page_text).to include("候補外として無視された選択ID: 2件。案件外または存在しないIDは、文書名やIDを表示せず集計だけで示します。")
    expect(document_choice_labels).to contain_exactly(a_string_including("Selected Manual"))
    expect(page_text).not_to include("Outside Project Manual", missing_document_id.to_s)

    expect do
      get project_ai_context_path(project, format: :json, mode: :compact, document_ids: mixed_document_ids)
    end.to change(AccessLog.where(target_type: "ai_context"), :count).by(1)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([selected.public_id])
    expect(AccessLog.where(target_type: "ai_context").last.target_name).to eq("mode=compact;scope=selected;selected_count=4;scoped_count=2;exported_count=1")

    get project_ai_context_path(project, candidate_view: :selected, document_ids: ["0", "-1", "not-a-number"])

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("現在は閲覧可能な文書全体（2件）を出力対象にしています。")
    expect(page_text).to include("出力候補（表示中2 / 全2件）")
    expect(page_text).not_to include("候補表示: 選択済みのみ")
    expect(document_choice_labels).to include(a_string_including("Selected Manual"), a_string_including("Other Manual"))
  end

  it "normalizes oversized document queries before filtering and rendering candidate links" do
    truncated_query = "manual-" + ("x" * (ProjectAiContextsController::DOCUMENT_QUERY_MAX_LENGTH - "manual-".length))
    long_query = "  #{truncated_query}ignored-tail  "
    matching = create_exportable_document(title: truncated_query, slug: "bounded-query", body: "Matched body text.")
    selected = create_exportable_document(title: "Selected Manual", slug: "selected-manual", body: "Selected body text.")
    create_exportable_document(title: "Ignored Tail Manual", slug: "ignored-tail", body: "Ignored body text.")

    sign_in_as(external_user)

    get project_ai_context_path(project, document_q: long_query, document_ids: [selected.id])

    expect(response).to have_http_status(:ok)
    query_field = parsed_html.at_css('input[name="document_q"]')
    expect(query_field["value"]).to eq(truncated_query)
    expect(query_field["maxlength"]).to eq(ProjectAiContextsController::DOCUMENT_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("検索条件: #{truncated_query}")
    expect(page_text).to include("出力候補（1件選択中、検索結果2 / 閲覧可能3件、表示中2件）")
    expect(document_choice_labels).to include(a_string_including(matching.title), a_string_including(selected.title))
    expect(document_choice_labels).not_to include(a_string_including("Ignored Tail Manual"))
    expect(ai_context_link_href("選択済みだけ表示")).to include("document_q=#{truncated_query}", "document_ids%5B%5D=#{selected.id}")

    get project_ai_context_path(project, format: :json, mode: :compact, document_q: long_query, document_ids: [selected.id])
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([selected.public_id])
  end

  it "bounds large HTML previews without changing all-scope export semantics" do
    documents = 55.times.map do |index|
      suffix = format("%03d", index)
      create_exportable_document(title: "Bulk Manual #{suffix}", slug: "bulk-#{suffix}", body: "Bulk body #{suffix}.")
    end

    sign_in_as(external_user)

    get project_ai_context_path(project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の候補: 50件 / 閲覧可能: 55件")
    expect(page_text).to include("checkbox候補は50件まで表示しています")
    expect(page_text).to include("含まれる文書は 50件だけ表示しています（全55件）。")
    expect(document_choice_labels.size).to eq(50)
    expect(document_choice_labels.first).to include("Bulk Manual 000")
    expect(document_choice_labels.last).to include("Bulk Manual 049")

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(55)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to include(documents.last.public_id)

    get project_ai_context_path(project, document_ids: [documents.last.id])
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("明示選択: 1件 / 案件内候補: 1件 / 出力対象: 1件")
    expect(document_choice_labels.size).to eq(51)
    expect(document_choice_labels.last).to include("Bulk Manual 054")

    get project_ai_context_path(project, document_q: "bulk-054")
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の候補: 1件 / 検索結果: 1件 / 閲覧可能: 55件")
    expect(page_text).to include("検索条件: bulk-054")
    expect(page_text).to include("出力候補（検索結果1 / 閲覧可能55件、表示中1件）")
    expect(document_choice_labels).to contain_exactly(a_string_including("Bulk Manual 054"))

    get project_ai_context_path(project, format: :json, mode: :compact, document_q: "bulk-054")
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(55)

    get project_ai_context_path(project, document_q: "bulk-000", document_ids: [documents.last.id])
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("明示選択: 1件 / 案件内候補: 1件 / 出力対象: 1件")
    expect(page_text).to include("出力候補（1件選択中、検索結果2 / 閲覧可能55件、表示中2件）")
    expect(document_choice_labels).to include(a_string_including("Bulk Manual 000"), a_string_including("Bulk Manual 054"))

    get project_ai_context_path(project, document_q: "bulk-000", document_ids: [documents.last.id], candidate_view: "selected")
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("候補表示: 選択済みのみ / 表示中: 1件 / 選択済み候補: 1件 / 閲覧可能: 55件")
    expect(page_text).to include("選択済み文書（表示中1件 / 選択済み候補1件）")
    expect(page_text).to include("選択済みのみ表示中です。検索条件に一致しない選択済み文書も、現在の出力対象として確認できます。")
    expect(document_choice_labels).to contain_exactly(a_string_including("Bulk Manual 054"))
    expect(ai_context_link_href("検索候補へ戻る")).to include("document_q=bulk-000", "document_ids%5B%5D=#{documents.last.id}")

    get project_ai_context_path(project, format: :json, mode: :compact, document_q: "bulk-000", document_ids: [documents.last.id], candidate_view: "selected")
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([documents.last.public_id])
  end

  it "records access logs for html and export responses with scope metadata" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    other_visible = create_exportable_document(title: "Other Manual", slug: "other", body: "Other body text.")
    internal = create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    sign_in_as(external_user)

    expect do
      get project_ai_context_path(project)
      get project_ai_context_path(project, format: :json, document_ids: [visible.id, internal.id])
      get project_ai_context_path(project, format: :md, mode: :full, document_ids: [visible.id, other_visible.id])
    end.to change(AccessLog.where(target_type: "ai_context"), :count).by(3)

    logs = AccessLog.where(target_type: "ai_context").order(:id).last(3)
    expect(logs.map(&:action_type)).to eq(%w[view download download])
    expect(logs.map(&:target_name)).to eq([
      "mode=compact;scope=all;selected_count=0;scoped_count=0;exported_count=2",
      "mode=compact;scope=selected;selected_count=2;scoped_count=2;exported_count=1",
      "mode=full;scope=selected;selected_count=2;scoped_count=2;exported_count=2"
    ])
  end

  it "keeps export responses available when access log creation fails" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    allow(AccessLog).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "audit unavailable")
    allow(Rails.logger).to receive(:error)

    sign_in_as(external_user)

    get project_ai_context_path(project, format: :json, mode: :compact)

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([visible.public_id])
    expect(AccessLog).to have_received(:create!).once
    expect(Rails.logger).to have_received(:error).with(include("AI context AccessLog skipped: ActiveRecord::StatementInvalid: audit unavailable"))
    expect(AccessLog.where(target_type: "ai_context")).to be_empty
  end
end
