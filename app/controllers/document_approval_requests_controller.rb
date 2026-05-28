class DocumentApprovalRequestsController < BaseController
  before_action :set_document_from_nested_route, only: %i[create]
  before_action :set_document_approval_request, only: %i[show update cancel]

  def index
    raise ApplicationError::Forbidden unless current_user.internal?

    base_relation = if params[:project_code].present?
      set_document_from_nested_route
      @document.document_approval_requests.includes(:requester, :approver, :acted_by)
    else
      DocumentApprovalRequest.includes(:document, :requester, :approver, :acted_by)
    end

    @status_filter = normalized_status_filter
    @pending_count = base_relation.pending.count
    @approved_count = base_relation.approved.count
    @cancelled_count = base_relation.cancelled.count

    scoped_relation = @status_filter.present? ? base_relation.where(status: @status_filter) : base_relation
    @document_approval_requests = scoped_relation.recent_first
    @document_approval_request_sections = build_sections(@document_approval_requests)
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
    redirect_to document_approval_request_path(@document_approval_request, return_to: @return_to_path), notice: "確認依頼を OK にしました。"
  end

  def cancel
    raise ApplicationError::Forbidden unless cancelable_request?

    @document_approval_request.cancel!(actor: current_user)
    redirect_to document_approval_request_path(@document_approval_request, return_to: @return_to_path), notice: "確認依頼を Cancel にしました。"
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
    @return_to_path = safe_return_to_path(document_approval_requests_path)
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

  def normalized_status_filter
    params[:status].presence_in(DocumentApprovalRequest.statuses.keys)
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

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return_to.start_with?("/") ? return_to : fallback
  end
end
