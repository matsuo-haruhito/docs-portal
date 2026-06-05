class Admin::ReadConfirmationsController < Admin::BaseController
  before_action :require_admin_only!

  DISPLAY_LIMIT = 200

  def index
    @projects = Project.order(:name, :id)
    @selected_project = selected_project
    @document_slug = params[:document_slug].to_s.strip
    @selected_user_id = params[:user_id].to_s.strip
    @selected_company_id = params[:company_id].to_s.strip
    @confirmed_from = parsed_date_param(:from)
    @confirmed_to = parsed_date_param(:to)
    @selected_document = selected_document if @selected_project
    @read_confirmation_companies = read_confirmation_companies
    @selected_company = selected_company
    @read_confirmation_users = read_confirmation_users
    @selected_user = selected_user
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

  def read_confirmation_companies
    return Company.none unless @selected_project
    return Company.none if @document_slug.present? && @selected_document.blank?

    Company
      .joins(users: { read_confirmations: :document })
      .where(documents: { project_id: @selected_project.id })
      .distinct
      .order(:name, :domain, :id)
  end

  def selected_company
    return if @selected_company_id.blank?

    @read_confirmation_companies.find { |company| company.id.to_s == @selected_company_id }
  end

  def read_confirmation_users
    return User.none unless @selected_project
    return User.none if @document_slug.present? && @selected_document.blank?
    return User.none if @selected_company_id.present? && @selected_company.blank?

    scope = User
      .joins(read_confirmations: :document)
      .where(documents: { project_id: @selected_project.id })
    scope = scope.where(company: @selected_company) if @selected_company
    scope
      .includes(:company)
      .distinct
      .order(:email_address, :id)
  end

  def selected_user
    return if @selected_user_id.blank?

    @read_confirmation_users.find { |user| user.id.to_s == @selected_user_id }
  end

  def filtered_read_confirmations
    return ReadConfirmation.none unless @selected_project
    return ReadConfirmation.none if @document_slug.present? && @selected_document.blank?
    return ReadConfirmation.none if @selected_company_id.present? && @selected_company.blank?
    return ReadConfirmation.none if @selected_user_id.present? && @selected_user.blank?

    scope = ReadConfirmation
      .joins(:document)
      .where(documents: { project_id: @selected_project.id })
    scope = scope.where(document: @selected_document) if @selected_document
    scope = scope.joins(user: :company).where(users: { company_id: @selected_company.id }) if @selected_company
    scope = scope.where(user: @selected_user) if @selected_user
    scope = scope.where("read_confirmations.confirmed_at >= ?", @confirmed_from.beginning_of_day) if @confirmed_from
    scope = scope.where("read_confirmations.confirmed_at <= ?", @confirmed_to.end_of_day) if @confirmed_to
    scope.includes(user: :company, document: :project)
      .order(confirmed_at: :desc, id: :desc)
      .limit(DISPLAY_LIMIT)
  end
end
