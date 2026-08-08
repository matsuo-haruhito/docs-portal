require "digest"
require "json"

class Api::Internal::MasterSyncsController < Api::BaseController
  MAX_REQUEST_BYTES = 1.megabyte

  before_action :authenticate_sync_request!

  def update
    unless supported_resource_type?
      idempotency_key
      parsed_payload
      render json: {
        status: "rejected",
        source_system: params[:source_system].to_s,
        resource_type: params[:resource_type].to_s,
        external_id: params[:external_id].to_s,
        error_code: "unsupported_resource_type",
        retryable: false,
        error: "resource_typeはcompany、project、documentのいずれかを指定してください"
      }, status: :unprocessable_content
      return
    end

    processor = request_processor

    if (replay = processor.replay_response)
      render_processor_response(replay)
      return
    end

    if read_only_maintenance?
      render json: {
        status: "deferred",
        error_code: "read_only_maintenance",
        retryable: true,
        error: "READ_ONLY_MAINTENANCE is enabled; master sync updates are paused."
      }, status: :service_unavailable
      return
    end

    render_processor_response(processor.call(payload: parsed_payload))
  end

  private

  def authenticate_sync_request!
    authenticate_bearer_token!("DOCS_PORTAL_SYNC_TOKEN")
  end

  def supported_resource_type?
    params[:resource_type].to_s.in?(ExternalMasterSyncMapping::RESOURCE_TARGET_TYPES.keys)
  end

  def request_processor
    @request_processor ||= MasterSync::RequestProcessor.new(
      idempotency_key:,
      request_digest:,
      source_system: params[:source_system].to_s,
      resource_type: params[:resource_type].to_s,
      external_id: params[:external_id].to_s
    )
  end

  def idempotency_key
    @idempotency_key ||= request.headers["Idempotency-Key"].to_s.strip.tap do |value|
      raise ApplicationError::BadRequest, "Idempotency-Key header is required" if value.blank?
      raise ApplicationError::BadRequest, "Idempotency-Key must be 255 characters or fewer" if value.length > 255
    end
  end

  def raw_request_body
    @raw_request_body ||= request.raw_post.tap do |body|
      raise ApplicationError::BadRequest, "JSON request body is required" if body.blank?
      raise ApplicationError::BadRequest, "request body is too large" if body.bytesize > MAX_REQUEST_BYTES
    end
  end

  def request_digest
    @request_digest ||= Digest::SHA256.hexdigest(
      [params[:source_system], params[:resource_type], params[:external_id], raw_request_body].join("\0")
    )
  end

  def parsed_payload
    @parsed_payload ||= JSON.parse(raw_request_body).tap do |payload|
      raise ApplicationError::BadRequest, "JSON request body must be an object" unless payload.is_a?(Hash)
    end
  rescue JSON::ParserError
    raise ApplicationError::BadRequest, "JSON request body is invalid"
  end

  def render_processor_response(result)
    response.set_header("Idempotency-Replayed", "true") if result.replayed
    render json: result.body, status: result.status
  end
end
