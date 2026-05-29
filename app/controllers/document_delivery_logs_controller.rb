class DocumentDeliveryLogsController < BaseController
  before_action :set_context, only: %i[new create]
  before_action :set_delivery_log, only: %i[show update]

  STATUS_FILTER_LABELS = {
    "draft" => "下書き",
    "sent" => "送付済み",
    "failed" => "失敗"
  }.freeze

  def index
    base_scope = current_user.internal? ? DocumentDeliveryLog.all : DocumentDeliveryLog.where(sender: current_user)

    @status_filter = normalized_status_filter
    @delivery_type_filter = normalized_delivery_type_filter
    @status_summary_counts = STATUS_FILTER_LABELS.keys.index_with { |status| base_scope.public_send(status).count }

    status_filter_scope = @delivery_type_filter.present? ? base_scope.public_send(@delivery_type_filter) : base_scope
    @status_filter_counts = STATUS_FILTER_LABELS.keys.index_with { |status| status_filter_scope.public_send(status).count }

    delivery_type_filter_scope = @status_filter.present? ? base_scope.public_send(@status_filter) : base_scope
    @delivery_type_counts = DocumentDeliveryLog.delivery_types.keys.index_with do |delivery_type|
      delivery_type_filter_scope.public_send(delivery_type).count
    end

    scoped_scope = base_scope
    scoped_scope = scoped_scope.public_send(@status_filter) if @status_filter.present?
    scoped_scope = scoped_scope.public_send(@delivery_type_filter) if @delivery_type_filter.present?
    @delivery_logs = scoped_scope.includes(:project, :document, :document_set, :sender).recent_first
  end

  def show
    raise ApplicationError::Forbidden unless visible_log?(@delivery_log)

    @return_to_path = safe_return_to_path(document_delivery_logs_path)
    @mailto_url = build_mailto_url(@delivery_log)
  end

  def new
    @delivery_log = build_delivery_log
  end

  def create
    @delivery_log = build_delivery_log(delivery_log_params)

    if @delivery_log.save
      redirect_to document_delivery_log_path(@delivery_log), notice: "送付下書きを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    raise ApplicationError::Forbidden unless visible_log?(@delivery_log)

    case params[:decision]
    when "mark_sent"
      @delivery_log.update!(status: :sent, sent_at: Time.current, error_message: nil)
      redirect_to document_delivery_log_path(@delivery_log), notice: "送付済みにしました。"
    when "mark_failed"
      @delivery_log.update!(status: :failed, error_message: params[:error_message].to_s.presence || "manual mark")
      redirect_to document_delivery_log_path(@delivery_log), notice: "送付失敗として記録しました。"
    else
      raise ApplicationError::BadRequest, "unsupported decision"
    end
  end

  private

  def set_context
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)

    @document =
      if params[:document_slug].present? || params[:slug].present?
        @project.documents.find_by!(slug: params[:document_slug] || params[:slug]).tap { require_document_access!(_1) }
      end

    @document_set =
      if params[:document_set_public_id].present? || params[:public_id].present?
        @project.document_sets.find_by!(public_id: params[:document_set_public_id] || params[:public_id]).tap do |set|
          raise ApplicationError::Forbidden unless set.viewable_by?(current_user)
        end
      end
  end

  def set_delivery_log
    @delivery_log = DocumentDeliveryLog.includes(:project, :document, :document_set, :sender).find_by!(public_id: params[:public_id])
  end

  def build_delivery_log(extra_attributes = {})
    DocumentDeliveryLogBuilder.new(
      sender: current_user,
      project: @project,
      document: @document,
      document_set: @document_set,
      attributes: default_attributes.merge(extra_attributes)
    ).build
  end

  def default_attributes
    {
      subject: default_subject,
      body: default_body,
      delivery_type: :portal_link
    }
  end

  def default_subject
    target_label = @document&.title || @document_set&.name || @project.name
    "[Document Portal] #{target_label}"
  end

  def default_body
    <<~TEXT.strip
      以下の資料をご確認ください。

      #{target_url}
    TEXT
  end

  def target_url
    if @document.present?
      project_document_url(@project, @document.slug)
    elsif @document_set.present?
      project_document_set_url(@project, @document_set)
    else
      project_url(@project)
    end
  end

  def delivery_log_params
    params.require(:document_delivery_log).permit(:to_addresses, :cc_addresses, :bcc_addresses, :subject, :body)
  end

  def visible_log?(log)
    current_user.internal? || log.sender == current_user
  end

  def build_mailto_url(log)
    query = {
      cc: log.cc_addresses,
      bcc: log.bcc_addresses,
      subject: log.subject,
      body: log.body
    }.compact.to_query
    "mailto:#{ERB::Util.url_encode(log.recipients.join(","))}?#{query}"
  end

  def normalized_status_filter
    params[:status].presence_in(DocumentDeliveryLog.statuses.keys)
  end

  def normalized_delivery_type_filter
    params[:delivery_type].presence_in(DocumentDeliveryLog.delivery_types.keys)
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return_to.start_with?("/") && !return_to.start_with?("//") ? return_to : fallback
  end
end
