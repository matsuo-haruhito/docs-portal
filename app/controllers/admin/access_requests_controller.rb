class Admin::AccessRequestsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @filters = filter_params
    scope = filtered_access_request_scope
    @access_requests = filtered_access_requests(scope)
    @status_counts = access_request_status_counts(scope, @access_requests)
  end

  def update
    access_request = AccessRequest.find_by!(public_id: params[:public_id])
    resolver = AccessRequestResolver.new(access_request:, approver: current_user)

    case params[:decision]
    when "approve"
      resolver.approve!
      notice = "アクセス申請を承認しました。"
    when "reject"
      resolver.reject!(reason: rejection_reason_param)
      notice = "アクセス申請を却下しました。"
    else
      raise ApplicationError::BadRequest, "unsupported decision"
    end

    redirect_to admin_access_requests_path(redirect_filter_params), notice:
  end

  private

  def filtered_access_request_scope
    scope = AccessRequest.recent_first.includes(:requester, :approver, :requestable)
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?
    scope
  end

  def filtered_access_requests(scope)
    if @filters[:q].present?
      scope = scope.where(
        access_request_search_condition,
        query: access_request_query_pattern(@filters[:q])
      )
    end

    scope.to_a
  end

  def access_request_query_pattern(query)
    "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
  end

  def access_request_search_condition
    <<~SQL.squish
      LOWER(access_requests.public_id) LIKE :query
      OR LOWER(access_requests.reason) LIKE :query
      OR EXISTS (
        SELECT 1
        FROM users requesters
        WHERE requesters.id = access_requests.requester_id
          AND (
            LOWER(requesters.name) LIKE :query
            OR LOWER(requesters.email_address) LIKE :query
          )
      )
      OR (
        access_requests.requestable_type = 'Project'
        AND EXISTS (
          SELECT 1
          FROM projects
          WHERE projects.id = access_requests.requestable_id
            AND (
              LOWER(projects.public_id) LIKE :query
              OR LOWER(projects.code) LIKE :query
              OR LOWER(projects.name) LIKE :query
            )
        )
      )
      OR (
        access_requests.requestable_type = 'Document'
        AND EXISTS (
          SELECT 1
          FROM documents
          LEFT JOIN projects document_projects ON document_projects.id = documents.project_id
          WHERE documents.id = access_requests.requestable_id
            AND (
              LOWER(documents.public_id) LIKE :query
              OR LOWER(documents.slug) LIKE :query
              OR LOWER(documents.title) LIKE :query
              OR LOWER(document_projects.code) LIKE :query
              OR LOWER(document_projects.name) LIKE :query
            )
        )
      )
      OR (
        access_requests.requestable_type = 'DocumentFile'
        AND EXISTS (
          SELECT 1
          FROM document_files
          LEFT JOIN document_versions ON document_versions.id = document_files.document_version_id
          LEFT JOIN documents file_documents ON file_documents.id = document_versions.document_id
          LEFT JOIN projects file_projects ON file_projects.id = file_documents.project_id
          WHERE document_files.id = access_requests.requestable_id
            AND (
              LOWER(document_files.public_id) LIKE :query
              OR LOWER(document_files.file_name) LIKE :query
              OR LOWER(document_files.search_text) LIKE :query
              OR LOWER(file_documents.title) LIKE :query
              OR LOWER(file_documents.slug) LIKE :query
              OR LOWER(file_projects.code) LIKE :query
              OR LOWER(file_projects.name) LIKE :query
            )
        )
      )
    SQL
  end

  def access_request_status_counts(scope, access_requests)
    return access_request_status_counts_from_loaded(access_requests) if @filters[:q].present?

    counts = scope.unscope(:order).group(:status).count
    AccessRequest.statuses.keys.to_h do |status|
      [status, counts[status].to_i]
    end
  end

  def access_request_status_counts_from_loaded(access_requests)
    AccessRequest.statuses.keys.to_h do |status|
      [status, access_requests.count { |access_request| access_request.status == status }]
    end
  end

  def rejection_reason_param
    reason = params[:rejection_reason].to_s.strip
    raise ApplicationError::BadRequest, "rejection_reason is required" if reason.blank?

    reason
  end

  def redirect_filter_params
    filter_params.compact
  end

  def filter_params
    permitted = params.permit(:status, :q).to_h.symbolize_keys
    status = permitted[:status].to_s

    {
      status: AccessRequest.statuses.key?(status) ? status : nil,
      q: permitted[:q].to_s.strip.presence
    }
  end
end