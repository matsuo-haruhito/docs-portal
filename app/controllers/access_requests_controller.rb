class AccessRequestsController < BaseController
  def index
    @status_filter = normalized_status_filter
    scope = AccessRequest.where(requester: current_user).recent_first.includes(:approver, :requestable)
    @status_counts = scope.unscope(:order).group(:status).count
    @access_requests = @status_filter.present? ? scope.public_send(@status_filter) : scope
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

  def normalized_status_filter
    status = params[:status].to_s
    return if status.blank?
    return status if AccessRequest.statuses.key?(status)

    nil
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
