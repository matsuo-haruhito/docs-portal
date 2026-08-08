module MasterSync
  class RequestProcessor
    Response = Data.define(:status, :body, :replayed)

    def initialize(idempotency_key:, request_digest:, source_system:, resource_type:, external_id:)
      @idempotency_key = idempotency_key
      @request_digest = request_digest
      @source_system = source_system
      @resource_type = resource_type
      @external_id = external_id
    end

    def replay_response
      receipt = MasterSyncReceipt.find_by(idempotency_key:)
      receipt && response_from_receipt(receipt)
    end

    def call(payload:)
      ApplicationRecord.transaction do
        AdvisoryLock.acquire!("master-sync-receipt:#{idempotency_key}")
        receipt = MasterSyncReceipt.find_by(idempotency_key:)

        if receipt
          response_from_receipt(receipt)
        else
          result = Upserter.new(source_system:, resource_type:, external_id:, payload:).call
          persist_response(result.status, result.body)
        end
      end
    rescue Upserter::MissingDependency => error
      transient_rejection(error.message)
    rescue Upserter::Unprocessable, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
      persist_rejection(error.message)
    end

    private

    attr_reader :idempotency_key, :request_digest, :source_system, :resource_type, :external_id

    def transient_rejection(message)
      Response.new(
        status: :unprocessable_content,
        body: {
          status: "deferred",
          source_system:,
          resource_type:,
          external_id:,
          error_code: "missing_dependency",
          retryable: true,
          error: message
        },
        replayed: false
      )
    end

    def persist_rejection(message)
      body = {
        status: "rejected",
        source_system:,
        resource_type:,
        external_id:,
        error: message
      }

      ApplicationRecord.transaction do
        AdvisoryLock.acquire!("master-sync-receipt:#{idempotency_key}")
        receipt = MasterSyncReceipt.find_by(idempotency_key:)
        receipt ? response_from_receipt(receipt) : persist_response(:unprocessable_content, body)
      end
    end

    def persist_response(status, body)
      receipt = MasterSyncReceipt.create!(
        idempotency_key:,
        request_digest:,
        source_system:,
        resource_type:,
        external_id:,
        response_status: Rack::Utils.status_code(status),
        response_body: body,
        completed_at: Time.current
      )
      response_from_receipt(receipt, replayed: false)
    end

    def response_from_receipt(receipt, replayed: true)
      if receipt.request_digest != request_digest
        return Response.new(
          status: :conflict,
          body: {
            status: "conflict",
            error: "同じIdempotency-Keyに異なるリクエストが指定されています"
          },
          replayed: false
        )
      end

      Response.new(status: receipt.response_status, body: receipt.response_body, replayed:)
    end
  end
end
