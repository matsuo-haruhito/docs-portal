class DocumentVersionsController < BaseController
  def show
    @version = DocumentVersion
      .includes(:document_files, document: [:project, :document_tags, :document_keywords])
      .find_by!(public_id: params[:public_id])
    require_document_version_view_access!(@version)

    @document = @version.document
    @project = @document.project
    return if require_consent!(target: @project, timing: :first_view)

    @versions = @document.document_versions.select { _1.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    visible_comments = @version.document_review_comments.visible_to(current_user)
    @question_threads = visible_comments.where(internal_only: false, comment_type: :question).roots.includes(:author, :resolved_by, replies: [:author, :resolved_by]).order(:created_at, :id)
    @review_comments = visible_comments.where(internal_only: true).includes(:author, :resolved_by).order(:created_at, :id)
    @export_preview_file = @version.document_files.select { _1.downloadable_by?(current_user) }.find do |file|
      file.effective_content_type.start_with?("application/pdf") || file.file_name.to_s.downcase.end_with?(".pdf")
    end
    @export_watermark_text =
      if @export_preview_file.present?
        ExportOutputPlan.new(project: @project, viewer: current_user, files: [@export_preview_file], include_source_path: false).call.items.first.watermark_text
      end
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end
end
