class AccessRequestsController < BaseController
  ACCESS_REQUEST_QUERY_MAX_LENGTH = 100
  ACCESS_REQUEST_LIST_LIMIT = 100
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  helper_method :access_request_query_max_length, :access_request_list_limit

  def index
    @status_filter = normalized_status_filter
    @query = normalized_query
    @requested_access_level_filter = normalized_requested_access_level_filter
    @requestable_type_filter = normalized_requestable_type_filter
    @page = normalized_page

    scope = AccessRequest.where(requester: current_user).recent_first.includes(:approver, :requestable)
    filtered_scope = filtered_access_request_scope(scope)
    @status_counts = access_request_status_counts(filtered_scope)
    filtered_scope = filtered_scope.where(status: @status_filter) if @status_filter.present?
    @access_request_total_count = filtered_scope.unscope(:order).count
    @total_pages = [(@access_request_total_count.to_f / ACCESS_REQUEST_LIST_LIMIT).ceil, 1].max
    @page = [@page, @total_pages].min
    @access_request_offset = (@page - 1) * ACCESS_REQUEST_LIST_LIMIT
    @access_requests = filtered_scope.offset(@access_request_offset).limit(ACCESS_REQUEST_LIST_LIMIT).to_a
    @access_request_start = @access_request_total_count.zero? ? 0 : @access_request_offset + 1
    @access_request_end = @access_request_offset + @access_requests.size
    @access_requests_truncated = @total_pages > 1
  end

  def create
    requestable = find_requestable
    requested_access_level = requested_access_level_param

    if read_only_maintenance_mode?
      redirect_back fallback_location: access_requests_path, alert: access_request_maintenance_message
      return
    end

    access_request = AccessRequest.find_or_initialize_by(
      requester: current_user,
      requestable:,
      requested_access_level:,
      status: :pending
    )
    access_request.reason = default_reason_for(requestable, requested_access_level)
    access_request.save!

    redirect_back fallback_location: access_requests_path, notice: "アクセス申請を送信しました。"
  end

  def cancel
    access_request = AccessRequest.find_by!(public_id: params[:public_id], requester: current_user)

    if read_only_maintenance_mode?
      redirect_to access_requests_path(cancel_return_filter_params), alert: access_request_maintenance_message
      return
    end

    AccessRequestResolver.new(access_request:, approver: nil).cancel!

    redirect_to access_requests_path(cancel_return_filter_params), notice: "アクセス申請を取り消しました。"
  end

  private

  def filtered_access_request_scope(scope)
    scope = scope.where(requested_access_level: @requested_access_level_filter) if @requested_access_level_filter.present?
    scope = scope.where(requestable_type: @requestable_type_filter) if @requestable_type_filter.present?
    scope = scope.where(access_request_query_sql, access_request_query_bindings) if @query.present?
    scope
  end

  def access_request_query_sql
    <<~SQL.squish
      LOWER(access_requests.reason) LIKE :query OR
      EXISTS (
        SELECT 1 FROM projects
        WHERE access_requests.requestable_type = 'Project'
          AND projects.id = access_requests.requestable_id
          AND (
            LOWER(projects.code) LIKE :query OR
            LOWER(projects.name) LIKE :query OR
            LOWER(projects.public_id) LIKE :query
          )
      ) OR
      EXISTS (
        SELECT 1 FROM documents
        LEFT JOIN projects ON projects.id = documents.project_id
        WHERE access_requests.requestable_type = 'Document'
          AND documents.id = access_requests.requestable_id
          AND (
            LOWER(documents.title) LIKE :query OR
            LOWER(documents.public_id) LIKE :query OR
            LOWER(projects.code) LIKE :query
          )
      ) OR
      EXISTS (
        SELECT 1 FROM document_files
        INNER JOIN document_versions ON document_versions.id = document_files.document_version_id
        INNER JOIN documents ON documents.id = document_versions.document_id
        LEFT JOIN projects ON projects.id = documents.project_id
        WHERE access_requests.requestable_type = 'DocumentFile'
          AND document_files.id = access_requests.requestable_id
          AND (
            LOWER(document_files.file_name) LIKE :query OR
            LOWER(document_files.public_id) LIKE :query OR
            LOWER(documents.title) LIKE :query OR
            LOWER(projects.code) LIKE :query
          )
      )
    SQL
  end

  def access_request_query_bindings
    { query: "%#{ActiveRecord::Base.sanitize_sql_like(@query.downcase)}%" }
  end

  def access_request_status_counts(scope)
    counts = scope.unscope(:order).group(:status).count
    AccessRequest.statuses.keys.to_h do |status|
      [status, counts[status].to_i]
    end
  end

  def cancel_return_filter_params
    {
      q: normalized_query,
      status: normalized_status_filter,
      requested_access_level: normalized_requested_access_level_filter,
      requestable_type: normalized_requestable_type_filter,
      page: normalized_page > 1 ? normalized_page : nil
    }.compact
  end

  def normalized_status_filter
    status = params[:status].to_s
    return if status.blank?
    return status if AccessRequest.statuses.key?(status)

    nil
  end

  def normalized_requested_access_level_filter
    requested_access_level = params[:requested_access_level].to_s
    return if requested_access_level.blank?
    return requested_access_level if AccessRequest.requested_access_levels.key?(requested_access_level)

    nil
  end

  def normalized_requestable_type_filter
    requestable_type = params[:requestable_type].to_s
    return if requestable_type.blank?
    return requestable_type if AccessRequest::SUPPORTED_REQUESTABLE_TYPES.include?(requestable_type)

    nil
  end

  def normalized_query
    params[:q].to_s.strip.presence&.slice(0, ACCESS_REQUEST_QUERY_MAX_LENGTH)
  end

  def normalized_page
    value = params[:page].to_s.strip
    value.match?(/\A\d+\z/) ? [value.to_i, 1].max : 1
  end

  def access_request_query_max_length
    ACCESS_REQUEST_QUERY_MAX_LENGTH
  end

  def access_request_list_limit
    ACCESS_REQUEST_LIST_LIMIT
  end

  def find_requestable
    case params[:requestable_type]
    when "Document"
      document = Document.find_by!(public_id: params[:requestable_public_id])
      require_document_access!(document)
      document
    when "DocumentFile"
      file = DocumentFile.find_by!(public_id: params[:requestable_public_id])
      require_document_version_view_access!(file.document_version)
      file
    when "Project"
      project = Project.find_by!(code: params[:requestable_public_id])
      require_project_access!(project)
      project
    else
      raise ApplicationError::BadRequest, "unsupported requestable type"
    end
  end

  def requested_access_level_param
    level = params[:requested_access_level].to_s
    raise ApplicationError::BadRequest, "requested_access_level is required" if level.blank?
    raise ApplicationError::BadRequest, "unsupported requested_access_level" unless AccessRequest.requested_access_levels.key?(level)

    level
  end

  def default_reason_for(requestable, requested_access_level)
    access_level_label = requested_access_level_label(requested_access_level)

    case requestable
    when Project
      "案件「#{requestable.name}」に#{access_level_label}権限が必要です。"
    when Document
      "文書「#{requestable.title}」に#{access_level_label}権限が必要です。"
    when DocumentFile
      "ファイル「#{requestable.file_name}」に#{access_level_label}権限が必要です。"
    else
      "追加のアクセス権限が必要です。"
    end
  end

  def requested_access_level_label(requested_access_level)
    case requested_access_level.to_s
    when "view"
      "閲覧"
    when "download"
      "ダウンロード"
    when "manage"
      "管理"
    else
      requested_access_level.to_s
    end
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def access_request_maintenance_message
    "メンテナンス中のためアクセス申請の送信と取消は停止しています。申請一覧と状態確認は継続できます。"
  end
end
