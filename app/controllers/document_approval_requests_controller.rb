class DocumentApprovalRequestsController < BaseController
  QUERY_MAX_LENGTH = 100
  USER_FILTER_SEARCH_LIMIT = 20
  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  before_action :set_document_from_nested_route, only: %i[create]
  before_action :set_document_approval_request, only: %i[show update cancel]

  def index
    raise ApplicationError::Forbidden unless current_user.internal?

    base_relation = approval_request_base_relation

    @status_filter = normalized_status_filter
    @query = normalized_query
    @requester_filter_id = normalized_user_filter_id(:requester_id)
    @approver_filter_id = normalized_user_filter_id(:approver_id)
    @page = normalized_page
    @per_page = normalized_per_page
    @requester_filter_options = filter_users_for(base_relation, :requester_id)
    @approver_filter_options = filter_users_for(base_relation, :approver_id)
    @selected_requester_filter = selected_role_user(base_relation, :requester_id, @requester_filter_id)
    @selected_approver_filter = selected_role_user(base_relation, :approver_id, @approver_filter_id)
    @pending_count = base_relation.pending.count
    @approved_count = base_relation.approved.count
    @cancelled_count = base_relation.cancelled.count

    scoped_relation = @status_filter.present? ? base_relation.where(status: @status_filter) : base_relation
    scoped_relation = apply_query_filter(scoped_relation) if @query.present?
    scoped_relation = apply_user_filter(scoped_relation, :requester_id, @requester_filter_id)
    scoped_relation = apply_user_filter(scoped_relation, :approver_id, @approver_filter_id)

    @document_approval_request_total_count = scoped_relation.count
    @total_pages = [(@document_approval_request_total_count.to_f / @per_page).ceil, 1].max
    @page = [@page, @total_pages].min
    @document_approval_request_offset = (@page - 1) * @per_page
    @document_approval_requests = scoped_relation.recent_first.offset(@document_approval_request_offset).limit(@per_page).to_a
    @document_approval_request_start = @document_approval_request_total_count.zero? ? 0 : @document_approval_request_offset + 1
    @document_approval_request_end = @document_approval_request_offset + @document_approval_requests.size
    @document_approval_request_sections = build_sections(@document_approval_requests)
  end

  def requester_search
    raise ApplicationError::Forbidden unless current_user.internal?

    render json: { options: role_user_options(searchable_role_users(approval_request_base_relation, :requester_id)) }
  end

  def selected_requester
    raise ApplicationError::Forbidden unless current_user.internal?

    render json: { option: role_user_option(selected_role_user(approval_request_base_relation, :requester_id, params[:id])) }
  end

  def approver_search
    raise ApplicationError::Forbidden unless current_user.internal?

    render json: { options: role_user_options(searchable_role_users(approval_request_base_relation, :approver_id)) }
  end

  def selected_approver
    raise ApplicationError::Forbidden unless current_user.internal?

    render json: { option: role_user_option(selected_role_user(approval_request_base_relation, :approver_id, params[:id])) }
  end

  def show
    raise ApplicationError::Forbidden unless showable_request?
  end

  def create
    if read_only_maintenance_mode?
      redirect_to project_document_path(@project, @document.slug), alert: document_approval_request_creation_maintenance_message
      return
    end

    document_approval_request = @document.document_approval_requests.new(create_params)
    document_approval_request.requester = current_user

    if document_approval_request.save
      redirect_to document_approval_request_path(document_approval_request, return_to: project_document_path(@project, @document.slug)), notice: "確認依頼を登録しました。"
    else
      redirect_to project_document_path(@project, @document.slug), alert: document_approval_request.errors.full_messages.join(", ")
    end
  end

  def update
    raise ApplicationError::Forbidden unless approvable_request?

    if read_only_maintenance_mode?
      redirect_to document_approval_request_path(@document_approval_request, return_to: @return_to_path), alert: document_approval_request_status_maintenance_message
      return
    end

    @document_approval_request.approve!(actor: current_user)
    redirect_to document_approval_request_path(@document_approval_request, return_to: @return_to_path), notice: "確認依頼を OK にしました。"
  end

  def cancel
    raise ApplicationError::Forbidden unless cancelable_request?

    if read_only_maintenance_mode?
      redirect_to document_approval_request_path(@document_approval_request, return_to: @return_to_path), alert: document_approval_request_status_maintenance_message
      return
    end

    @document_approval_request.cancel!(actor: current_user)
    redirect_to document_approval_request_path(@document_approval_request, return_to: @return_to_path), notice: "確認依頼を Cancel にしました。"
  end

  private

  def approval_request_base_relation
    if params[:project_code].present?
      set_document_from_nested_route
      @document.document_approval_requests.includes(:requester, :approver, :acted_by)
    else
      DocumentApprovalRequest.includes(:document, :requester, :approver, :acted_by)
    end
  end

  def set_document_from_nested_route
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @document = @project.documents.find_by!(slug: params[:document_slug] || params[:slug])
    require_document_access!(@document)
  end

  def set_document_approval_request
    @document_approval_request = DocumentApprovalRequest.includes(:document, :requester, :approver, :acted_by).find_by!(public_id: params[:public_id])
    @document = @document_approval_request.document
    @project = @document.project
    @return_to_path = safe_return_to_path(default_return_to_path)
    require_document_access!(@document)
  end

  def create_params
    params.require(:document_approval_request).permit(:title, :body, :approver_id)
  end

  def showable_request?
    current_user.internal? || current_user == @document_approval_request.requester
  end

  def approvable_request?
    @document_approval_request.pending? && current_user.internal?
  end

  def cancelable_request?
    @document_approval_request.pending? && (current_user.internal? || current_user == @document_approval_request.requester)
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def document_approval_request_creation_maintenance_message
    "メンテナンス中のため確認依頼の新規作成は停止しています。確認依頼の一覧や詳細の閲覧は継続できます。"
  end

  def document_approval_request_status_maintenance_message
    "メンテナンス中のため確認依頼のOK / Cancelは停止しています。確認依頼の一覧や詳細の閲覧は継続できます。"
  end

  def normalized_status_filter
    params[:status].presence_in(DocumentApprovalRequest.statuses.keys)
  end

  def normalized_query
    params[:q].to_s.strip.presence&.slice(0, QUERY_MAX_LENGTH)
  end

  def normalized_user_filter_id(param_name)
    value = params[param_name].to_s.strip
    value.match?(/\A\d+\z/) ? value : nil
  end

  def normalized_page
    value = params[:page].to_s.strip
    value.match?(/\A\d+\z/) ? [value.to_i, 1].max : 1
  end

  def normalized_per_page
    value = params[:per_page].to_s.strip
    per_page = value.match?(/\A\d+\z/) ? value.to_i : DEFAULT_PER_PAGE
    per_page = DEFAULT_PER_PAGE if per_page < 1
    [per_page, MAX_PER_PAGE].min
  end

  def filter_users_for(relation, foreign_key)
    role_user_scope(relation, foreign_key)
  end

  def role_user_scope(relation, foreign_key)
    user_ids = relation.reselect(foreign_key).where.not(foreign_key => nil).distinct
    User.where(id: user_ids).order(:name, :email_address, :id)
  end

  def searchable_role_users(relation, foreign_key)
    scope = role_user_scope(relation, foreign_key)
    query = normalized_user_search_query(params[:q])
    return scope.limit(USER_FILTER_SEARCH_LIMIT) if query.blank?

    pattern = "%#{User.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(users.name) LIKE :pattern OR LOWER(users.email_address) LIKE :pattern",
      pattern:
    ).limit(USER_FILTER_SEARCH_LIMIT)
  end

  def selected_role_user(relation, foreign_key, user_id)
    return if user_id.blank?

    role_user_scope(relation, foreign_key).find_by(id: user_id)
  end

  def normalized_user_search_query(value)
    value.to_s.strip.first(QUERY_MAX_LENGTH)
  end

  def role_user_options(users)
    users.map { role_user_option(_1) }
  end

  def role_user_option(user)
    return if user.blank?

    { value: user.id, text: role_user_label(user) }
  end

  def role_user_label(user)
    primary_label = user.display_name.presence || user.email_address
    primary_label == user.email_address ? primary_label : "#{primary_label} / #{user.email_address}"
  end

  def apply_user_filter(relation, foreign_key, user_id)
    return relation if user_id.blank?

    relation.where(foreign_key => user_id)
  end

  def apply_query_filter(relation)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    relation.left_outer_joins(:document).where(
      <<~SQL.squish,
        document_approval_requests.title ILIKE :pattern
        OR document_approval_requests.body ILIKE :pattern
        OR documents.title ILIKE :pattern
        OR documents.slug ILIKE :pattern
        OR EXISTS (
          SELECT 1 FROM users requester_search
          WHERE requester_search.id = document_approval_requests.requester_id
            AND requester_search.name ILIKE :pattern
        )
        OR EXISTS (
          SELECT 1 FROM users approver_search
          WHERE approver_search.id = document_approval_requests.approver_id
            AND approver_search.name ILIKE :pattern
        )
      SQL
      pattern:
    )
  end

  def build_sections(requests)
    return [[status_section_title(@status_filter), requests]] if @status_filter.present?

    pending_requests = requests.select(&:pending?)
    processed_requests = requests.reject(&:pending?)

    [["対応待ち", pending_requests], ["処理済み", processed_requests]]
  end

  def status_section_title(status)
    case status
    when "pending"
      "対応待ち"
    when "approved"
      "OK済み"
    when "cancelled"
      "Cancel済み"
    else
      "確認依頼"
    end
  end

  def default_return_to_path
    current_user.internal? ? document_approval_requests_path : project_document_path(@project, @document.slug)
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return safe_internal_return_to_path?(return_to) ? return_to : fallback
  end

  def safe_internal_return_to_path?(path)
    return false if path.blank? || path.match?(/[[:cntrl:]]/)
    return false unless path.start_with?("/") && !path.start_with?("//")

    uri = URI.parse(path)
    uri.scheme.blank? && uri.host.blank? && uri.path.start_with?("/")
  rescue URI::InvalidURIError
    false
  end
end
