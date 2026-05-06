class DocumentApprovalRequestsController < BaseController
  before_action :set_document_from_nested_route, only: %i[create]
  before_action :set_document_approval_request, only: %i[show update cancel]

  def index
    raise ApplicationError::Forbidden unless current_user.internal?

    if params[:project_code].present?
      set_document_from_nested_route
      @document_approval_requests = @document.document_approval_requests.recent_first.includes(:requester, :approver, :acted_by)
    else
      @document_approval_requests = DocumentApprovalRequest.recent_first.includes(:document, :requester, :approver, :acted_by)
    end
  end

  def show
    raise ApplicationError::Forbidden unless showable_request?
  end

  def create
    document_approval_request = @document.document_approval_requests.new(create_params)
    document_approval_request.requester = current_user

    if document_approval_request.save
      redirect_to document_approval_request_path(document_approval_request), notice: "確認依頼を登録しました。"
    else
      redirect_to project_document_path(@project, @document.slug), alert: document_approval_request.errors.full_messages.join(", ")
    end
  end

  def update
    raise ApplicationError::Forbidden unless current_user.internal?

    @document_approval_request.approve!(actor: current_user)
    redirect_to document_approval_request_path(@document_approval_request), notice: "確認依頼を OK にしました。"
  end

  def cancel
    raise ApplicationError::Forbidden unless cancelable_request?

    @document_approval_request.cancel!(actor: current_user)
    redirect_to document_approval_request_path(@document_approval_request), notice: "確認依頼を Cancel にしました。"
  end

  private

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
    require_document_access!(@document)
  end

  def create_params
    params.require(:document_approval_request).permit(:title, :body, :approver_id)
  end

  def showable_request?
    current_user.internal? || current_user == @document_approval_request.requester
  end

  def cancelable_request?
    @document_approval_request.pending? && (current_user.internal? || current_user == @document_approval_request.requester)
  end
end
