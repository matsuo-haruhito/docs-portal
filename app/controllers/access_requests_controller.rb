class AccessRequestsController < BaseController
  def index
    @access_requests = AccessRequest.where(requester: current_user).recent_first.includes(:approver, :requestable)
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
    case requestable
    when Project
      "Need #{requested_access_level} access to project #{requestable.name}."
    when Document
      "Need #{requested_access_level} access to document #{requestable.title}."
    when DocumentFile
      "Need #{requested_access_level} access to file #{requestable.file_name}."
    else
      "Need additional access."
    end
  end
end
