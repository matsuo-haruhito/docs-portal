class AccessRequestsController < BaseController
  def index
    @status_filter = normalized_status_filter
    @query = normalized_query

    scope = AccessRequest.where(requester: current_user).recent_first.includes(:approver, :requestable)
    @access_requests = filtered_access_requests(scope)
    @status_counts = access_request_status_counts(scope, @access_requests)
    @access_requests = @access_requests.select { |access_request| access_request.status == @status_filter } if @status_filter.present?
  end

  def create
    requestable = find_requestable
    requested_access_level = requested_access_level_param

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
    AccessRequestResolver.new(access_request:, approver: nil).cancel!

    redirect_to access_requests_path, notice: "アクセス申請を取り消しました。"
  end

  private

  def filtered_access_requests(scope)
    requests = scope.to_a
    return requests if @query.blank?

    requests.select { |access_request| access_request_matches_query?(access_request, @query) }
  end

  def access_request_matches_query?(access_request, query)
    access_request_search_text(access_request).include?(query.downcase)
  end

  def access_request_search_text(access_request)
    request_hash = AccessRequestHash.new(access_request).call
    requestable = request_hash[:requestable] || {}

    [
      request_hash[:reason],
      requestable[:code],
      requestable[:name],
      requestable[:project_code],
      requestable[:title],
      requestable[:document_title],
      requestable[:file_name],
      requestable[:public_id]
    ].compact.join(" ").downcase
  end

  def access_request_status_counts(scope, access_requests)
    return access_request_status_counts_from_loaded(access_requests) if @query.present?

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

  def normalized_status_filter
    status = params[:status].to_s
    return if status.blank?
    return status if AccessRequest.statuses.key?(status)

    nil
  end

  def normalized_query
    params[:q].to_s.strip.presence
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
end
