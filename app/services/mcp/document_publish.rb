module Mcp
  class DocumentPublish
    IDEMPOTENCY_KEY_RANGE = 8..200

    def self.preview(user:, application:, version_public_id:)
      new(user:, application:, version_public_id:).preview
    end

    def self.apply(user:, application:, version_public_id:, confirmation_token:, idempotency_key:)
      new(user:, application:, version_public_id:).apply(confirmation_token:, idempotency_key:)
    end

    def initialize(user:, application:, version_public_id:)
      @user = user
      @application = application
      @version_public_id = version_public_id
    end

    def preview
      version = publishable_version
      quality = quality_result(version)
      raise ApplicationError::BadRequest, "品質チェックのエラーを解消してください" unless quality.pass?

      {
        document_public_id: version.document.public_id,
        document_version_public_id: version.public_id,
        warnings: quality.warnings.map { check_hash(_1) },
        confirmation_token: verifier.generate(signed_payload(version, quality), expires_in: 10.minutes),
        expires_in_seconds: 600
      }
    end

    def apply(confirmation_token:, idempotency_key:)
      validate_idempotency_key!(idempotency_key)
      signed = verifier.verify(confirmation_token).deep_symbolize_keys
      verify_replay_identity!(signed)
      key_digest = Digest::SHA256.hexdigest(idempotency_key)
      request_digest = signed.fetch(:publish_digest)
      existing = receipt_scope(key_digest).first
      return replay(existing, request_digest) if existing
      raise ApplicationError::BadRequest, "メンテナンス中は文書版を公開できません" if read_only_maintenance?

      version = publishable_version
      quality = quality_result(version)
      expected = signed_payload(version, quality)
      raise ApplicationError::BadRequest, "公開確認内容が一致しません" unless secure_payload_match?(signed, expected)

      response = nil
      Document.transaction do
        version.lock!
        version.document.lock!
        quality = quality_result(version)
        current = signed_payload(version, quality)
        raise ApplicationError::BadRequest, "preview後に文書版または品質結果が変更されました" unless secure_payload_match?(signed, current)
        raise ApplicationError::BadRequest, "品質チェックのエラーを解消してください" unless quality.pass?

        existing = receipt_scope(key_digest).lock.first
        return replay(existing, request_digest) if existing

        before = { status: version.status, latest_version_public_id: version.document.latest_version&.public_id }
        ManualDocumentUploadReview.new(version:, actor: user).approve!
        response = {
          status: "published",
          document_public_id: version.document.public_id,
          document_version_public_id: version.public_id,
          published_at: version.reload.published_at.iso8601
        }
        McpMutationReceipt.create!(
          oauth_application: application,
          user:,
          document: version.document,
          document_version: version,
          operation: "publish_revision",
          idempotency_key_digest: key_digest,
          request_digest:,
          before_json: before,
          after_json: { status: version.status, latest_version_public_id: version.document.reload.latest_version&.public_id },
          response_json: response,
          completed_at: Time.current
        )
      end
      publish_notification(version)
      response
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ApplicationError::BadRequest, "公開確認tokenが無効または期限切れです"
    end

    private

    attr_reader :user, :application, :version_public_id

    def publishable_version
      raise ApplicationError::Forbidden unless user.internal?
      version = DocumentVersion.includes(:document).find_by!(public_id: version_public_id)
      raise ApplicationError::BadRequest, "この文書はdocs-portalが正本ではありません" unless version.document.source_authority_docs_portal?
      raise ApplicationError::BadRequest, "draft版だけ公開できます" unless version.draft?
      raise ApplicationError::BadRequest, "MCPまたは手動改訂のdraft版だけ公開できます" unless version.source_commit_hash == ManualDocumentUploadReview::MANUAL_UPLOAD_SOURCE

      version
    end

    def quality_result(version)
      DocumentVersionQualityChecker.new(version).call
    end

    def signed_payload(version, quality)
      payload = {
        user_public_id: user.public_id,
        application_uid: application.uid,
        document_public_id: version.document.public_id,
        document_version_public_id: version.public_id,
        document_updated_at: version.document.updated_at.iso8601(6),
        version_updated_at: version.updated_at.iso8601(6),
        quality_digest: quality_digest(quality)
      }
      payload.merge(publish_digest: Digest::SHA256.hexdigest(JSON.generate(payload.sort.to_h)))
    end

    def quality_digest(quality)
      Digest::SHA256.hexdigest(JSON.generate(quality.checks.map { check_hash(_1) }))
    end

    def check_hash(check)
      { key: check.key, severity: check.severity, message: check.message, detail: check.detail }
    end

    def secure_payload_match?(actual, expected)
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(JSON.generate(actual.sort.to_h)),
        Digest::SHA256.hexdigest(JSON.generate(expected.sort.to_h))
      )
    end

    def receipt_scope(key_digest)
      McpMutationReceipt.where(
        oauth_application: application,
        user:,
        operation: "publish_revision",
        idempotency_key_digest: key_digest
      )
    end

    def replay(receipt, request_digest)
      raise ApplicationError::BadRequest, "idempotency_keyが異なる内容で使用されています" unless receipt.request_digest == request_digest

      receipt.response_json.deep_symbolize_keys
    end

    def publish_notification(version)
      NotificationEventPublisher.new(actor_user: user).publish_document_published!(document_version: version)
    rescue StandardError => e
      Rails.logger.error("MCP publish notification failed: #{e.class}: #{e.message}")
    end

    def verify_replay_identity!(signed)
      valid = signed[:user_public_id] == user.public_id &&
        signed[:application_uid] == application.uid &&
        signed[:document_version_public_id] == version_public_id
      raise ApplicationError::BadRequest, "公開確認内容が一致しません" unless valid
    end

    def validate_idempotency_key!(value)
      raise ApplicationError::BadRequest, "idempotency_keyは8〜200文字で指定してください" unless IDEMPOTENCY_KEY_RANGE.cover?(value.to_s.length)
    end

    def verifier
      Rails.application.message_verifier(:mcp_document_publish)
    end

    def read_only_maintenance?
      ActiveModel::Type::Boolean.new.cast(ENV["READ_ONLY_MAINTENANCE"])
    end
  end
end
