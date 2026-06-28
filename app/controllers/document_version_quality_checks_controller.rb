class DocumentVersionQualityChecksController < BaseController
  QUALITY_CHECK_SEVERITIES = %w[error warning info].freeze

  before_action :set_version
  before_action :require_internal_viewer!

  def show
    @result = DocumentVersionQualityChecker.new(@version).call
    @quality_check_hash = DocumentVersionQualityCheckHash.new(@result).call
    set_table_filters

    respond_to do |format|
      format.html
      format.json { render json: @quality_check_hash }
      format.md do
        render plain: DocumentVersionQualityCheckMarkdown.new(@result).call,
          content_type: "text/markdown; charset=utf-8"
      end
    end
  end

  private

  def set_version
    @version = DocumentVersion.find_by!(public_id: params[:document_version_public_id] || params[:public_id])
    require_document_version_view_access!(@version)
    @document = @version.document
    @project = @document.project
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def set_table_filters
    checks = @quality_check_hash.fetch(:checks)
    requested_severity = params[:severity].to_s.presence
    requested_key = params[:key].to_s.presence

    @quality_check_key_options = checks.map { |check| check[:key].to_s }.uniq.sort
    @quality_check_severity_filter = requested_severity if QUALITY_CHECK_SEVERITIES.include?(requested_severity)
    @quality_check_key_filter = requested_key if @quality_check_key_options.include?(requested_key)

    @filtered_quality_checks = checks.select do |check|
      severity_matches = @quality_check_severity_filter.blank? || check[:severity].to_s == @quality_check_severity_filter
      key_matches = @quality_check_key_filter.blank? || check[:key].to_s == @quality_check_key_filter

      severity_matches && key_matches
    end
  end

  def require_internal_viewer!
    raise ApplicationError::Forbidden unless current_user&.internal?
  end
end
