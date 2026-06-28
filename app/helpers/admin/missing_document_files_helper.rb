module Admin::MissingDocumentFilesHelper
  MISSING_DOCUMENT_FILE_HANDOFF_LIMIT = 5

  def missing_document_file_expected_path_preview(file)
    normalized_key = file.storage_key.to_s.tr("\\", "/").delete_prefix("/")
    relative_path = Pathname.new(normalized_key.presence || "document-file").cleanpath.to_s

    if relative_path.blank? || relative_path == "." || relative_path == ".." || relative_path.start_with?("../")
      return "storage/document_files/[invalid storage key]"
    end

    File.join("storage", "document_files", relative_path)
  end

  def missing_document_file_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def missing_document_file_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: missing_document_file_project_option_label(project) }
  end

  def missing_document_file_handoff_digest(health:, filters:, selected_project:, display_limit:)
    representative_files = health.missing_files.first(MISSING_DOCUMENT_FILE_HANDOFF_LIMIT)
    lines = [
      "# 欠落文書ファイル handoff",
      "",
      "## 現在条件",
      "- 案件: #{missing_document_file_project_filter_label(filters, selected_project)}",
      "- 文書: #{missing_document_file_filter_label(filters[:document_q])}",
      "- ファイル: #{missing_document_file_filter_label(filters[:file_q])}",
      "",
      "## 件数",
      "- 登録ファイル数: #{health.total_count}",
      "- 全体欠落数: #{health.missing_count}",
      "- 条件一致欠落数: #{health.filtered? ? health.filtered_missing_count : health.missing_count}",
      "- 表示上限: 先頭#{display_limit}件",
      "- 表示中件数: #{health.missing_files.size}",
      "",
      "## 代表 missing file（表示中先頭#{representative_files.size}件）"
    ]

    if representative_files.any?
      representative_files.each.with_index(1) do |file, index|
        lines.concat(missing_document_file_handoff_file_lines(file, index))
      end
    else
      lines << "- なし"
    end

    lines.concat([
      "",
      "## 注意",
      "- 表示中は先頭#{display_limit}件までです。全体欠落や条件一致全件を保証する export ではありません。",
      "- この digest は read-only の引き継ぎ用です。自動修復、削除、再import、CSV export は行いません。",
      "- Expected path は画面と同じ safe preview です。raw absolute path や storage backend private path は含めません。"
    ])

    lines.join("\n")
  end

  def missing_document_file_filter_summary_labels(filters, selected_project)
    labels = []
    labels << "案件=#{selected_project ? selected_project.name : filters[:project_id]}" if filters[:project_id].present?
    labels << "文書=#{filters[:document_q]}" if filters[:document_q].present?
    labels << "ファイル=#{filters[:file_q]}" if filters[:file_q].present?
    labels
  end

  private

  def missing_document_file_handoff_file_lines(file, index)
    version = file.document_version
    document = version.document
    project = document.project

    [
      "#{index}. #{project.name} / #{document.title} / #{version.version_label}",
      "   - file_name: #{missing_document_file_filter_label(file.file_name)}",
      "   - storage_key: #{missing_document_file_filter_label(file.storage_key)}",
      "   - expected_path: #{missing_document_file_expected_path_preview(file)}"
    ]
  end

  def missing_document_file_project_filter_label(filters, selected_project)
    return "未指定" if filters[:project_id].blank?

    selected_project ? missing_document_file_project_option_label(selected_project) : filters[:project_id].to_s
  end

  def missing_document_file_filter_label(value)
    value.to_s.presence || "未指定"
  end
end
