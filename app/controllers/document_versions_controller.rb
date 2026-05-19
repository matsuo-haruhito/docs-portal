class DocumentVersionsController < BaseController
  def show
    @version = DocumentVersion
      .includes(:document_files, document: [:project, :document_tags, :document_keywords])
      .find_by!(public_id: params[:public_id])
    require_document_version_view_access!(@version)

    @document = @version.document
    @project = @document.project
    return if require_consent!(target: @project, timing: :first_view)

    @versions = @document.document_versions.includes(:document_files).select { |version| version.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @previous_version = previous_viewable_version
    @compare_version = selected_compare_version || @previous_version
    @compare_version_options = compare_version_options
    @version_file_diff_summary = build_file_diff_summary(@version, @compare_version)
    @markdown_line_diffs = MarkdownLineDiffBuilder.new(
      current_version: @version,
      previous_version: @compare_version,
      file_rows: @version_file_diff_summary.fetch(:files)
    ).call
    @rendered_html_diff = RenderedHtmlDiffBuilder.new(
      current_version: @version,
      previous_version: @compare_version
    ).call
    visible_comments = @version.document_review_comments.visible_to(current_user)
    @question_threads = visible_comments.where(internal_only: false, comment_type: :question).roots.includes(:author, :resolved_by, replies: [:author, :resolved_by]).order(:created_at, :id)
    @review_comments = visible_comments.where(internal_only: true).includes(:author, :resolved_by).order(:created_at, :id)
    @export_preview_file = @version.document_files.select { |file| file.downloadable_by?(current_user) }.find do |file|
      file.effective_content_type.start_with?("application/pdf") || file.file_name.to_s.downcase.end_with?(".pdf")
    end
    @export_watermark_text =
      if @export_preview_file.present?
        ExportOutputPlan.new(project: @project, viewer: current_user, files: [@export_preview_file], include_source_path: false).call.items.first.watermark_text
      end
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  private

  def selected_compare_version
    return if params[:compare_version_id].blank?

    @versions.find { |version| version.public_id == params[:compare_version_id] && version != @version }
  end

  def compare_version_options
    @versions.reject { |version| version == @version }
  end

  def previous_viewable_version
    @versions
      .select { |version| version.created_at < @version.created_at }
      .max_by(&:created_at)
  end

  def build_file_diff_summary(version, previous_version)
    current_files = version.document_files.to_a
    previous_files = previous_version&.document_files&.to_a || []
    current_by_path = current_files.index_by { |file| file_diff_path(file) }
    previous_by_path = previous_files.index_by { |file| file_diff_path(file) }

    current_paths = current_by_path.keys
    previous_paths = previous_by_path.keys
    added_paths = current_paths - previous_paths
    removed_paths = previous_paths - current_paths
    changed_paths = (current_paths & previous_paths).select do |path|
      file_diff_signature(current_by_path.fetch(path)) != file_diff_signature(previous_by_path.fetch(path))
    end

    files = []
    changed_paths.each do |path|
      file = current_by_path.fetch(path)
      files << file_diff_row(status: :changed, path: path, file: file, previous_file: previous_by_path[path])
    end
    added_paths.each do |path|
      files << file_diff_row(status: :added, path: path, file: current_by_path.fetch(path), previous_file: nil)
    end
    removed_paths.each do |path|
      previous_file = previous_by_path.fetch(path)
      files << file_diff_row(status: :removed, path: path, file: previous_file, previous_file: previous_file)
    end

    {
      changed_count: changed_paths.size,
      added_count: added_paths.size,
      removed_count: removed_paths.size,
      files: files.sort_by { |row| [file_diff_status_order(row.fetch(:status)), row.fetch(:path)] }
    }
  end

  def file_diff_row(status:, path:, file:, previous_file:)
    previous_size = previous_file&.file_size.to_i
    current_size = status == :removed ? 0 : file.file_size.to_i

    {
      status: status,
      path: path,
      file: file,
      previous_file: previous_file,
      added_bytes: [current_size - previous_size, 0].max,
      removed_bytes: [previous_size - current_size, 0].max
    }
  end

  def file_diff_path(file)
    file.tree_path.presence || file.file_name
  end

  def file_diff_signature(file)
    [file.file_size, file.content_type, file.file_name, file.storage_key]
  end

  def file_diff_status_order(status)
    { changed: 0, added: 1, removed: 2 }.fetch(status)
  end
end