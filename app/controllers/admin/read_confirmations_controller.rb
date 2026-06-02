class Admin::ReadConfirmationsController < Admin::BaseController
  before_action :require_admin_only!

  DISPLAY_LIMIT = 200

  def index
    @projects = Project.order(:name, :id)
    @selected_project = selected_project
    @document_slug = params[:document_slug].to_s.strip
    @confirmed_from = parsed_date_param(:from)
    @confirmed_to = parsed_date_param(:to)
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

  def parsed_date_param(name)
    value = params[name].to_s.strip
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def filtered_read_confirmations
    return ReadConfirmation.none unless @selected_project
    return ReadConfirmation.none if @document_slug.present? && @selected_document.blank?

    scope = ReadConfirmation
      .joins(:document)
      .where(documents: { project_id: @selected_project.id })
    scope = scope.where(document: @selected_document) if @selected_document
    scope = scope.where("read_confirmations.confirmed_at >= ?", @confirmed_from.beginning_of_day) if @confirmed_from
    scope = scope.where("read_confirmations.confirmed_at <= ?", @confirmed_to.end_of_day) if @confirmed_to
    scope.includes(:user, document: :project)
      .order(confirmed_at: :desc, id: :desc)
      .limit(DISPLAY_LIMIT)
  end
end
