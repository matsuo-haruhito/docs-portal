class Admin::ReadConfirmationsController < Admin::BaseController
  before_action :require_admin_only!

  DISPLAY_LIMIT = 200

  def index
    @projects = Project.order(:name, :id)
    @selected_project = selected_project
    @document_slug = params[:document_slug].to_s.strip
    @selected_document = selected_document if @selected_project
    @read_confirmations = filtered_read_confirmations
  end

  private

  def selected_project
    return if params[:project_id].blank?

    @projects.find_by(id: params[:project_id])
  end

  def selected_document
    return if @document_slug.blank?

    @selected_project.documents.find_by(slug: @document_slug)
  end

  def filtered_read_confirmations
    return ReadConfirmation.none unless @selected_project
    return ReadConfirmation.none if @document_slug.present? && @selected_document.blank?

    scope = ReadConfirmation
      .joins(:document)
      .where(documents: { project_id: @selected_project.id })
    scope = scope.where(document: @selected_document) if @selected_document
    scope.includes(:user, document: :project)
      .order(confirmed_at: :desc, id: :desc)
      .limit(DISPLAY_LIMIT)
  end
end
