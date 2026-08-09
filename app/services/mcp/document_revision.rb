require "tempfile"

module Mcp
  class DocumentRevision
    BODY_MAX_BYTES = 1.megabyte
    IDEMPOTENCY_KEY_RANGE = 8..200
    METADATA_FIELDS = %w[title category document_kind visibility_policy importance_level reading_note recommended_sort_order].freeze

    def self.preview(user:, application:, attributes:)
      new(user:, application:, attributes:).preview
    end

    def self.apply(user:, application:, attributes:, confirmation_token:, idempotency_key:)
      new(user:, application:, attributes:).apply(confirmation_token:, idempotency_key:)
    end

    def initialize(user:, application:, attributes:)
      @user = user
      @application = application
      @attributes = attributes.to_h.deep_stringify_keys
    end

    def preview
      context = revision_context
      payload = signed_payload(context)
      {
        operation: context.fetch(:document) ? "revise" : "create",
        project_code: context.fetch(:project).code,
        document_public_id: context[:document]&.public_id,
        base_version_public_id: context[:base_version]&.public_id,
        source_path: normalized.fetch("source_path"),
        body_sha256: body_digest,
        body_bytes: body.bytesize,
        body_lines: body.lines.count,
        metadata_changes: metadata_changes(context[:document]),
        confirmation_token: verifier.generate(payload, expires_in: 10.minutes),
        expires_in_seconds: 600
      }
    end

    def apply(confirmation_token:, idempotency_key:)
      validate_idempotency_key!(idempotency_key)
      signed = verifier.verify(confirmation_token).deep_symbolize_keys
      verify_replay_identity!(signed)
      key_digest = Digest::SHA256.hexdigest(idempotency_key)
      request_digest = signed.fetch(:revision_digest)
      existing = receipt_scope("apply_revision", key_digest).first
      return replay(existing, request_digest) if existing
      raise ApplicationError::BadRequest, "メンテナンス中は文書改訂を適用できません" if read_only_maintenance?

      context = revision_context
      expected = signed_payload(context)
      raise ApplicationError::BadRequest, "確認内容が一致しません" unless secure_payload_match?(signed, expected)

      response = nil
      Document.transaction do
        lock_and_verify_context!(context, signed)
        existing = receipt_scope("apply_revision", key_digest).lock.first
        return replay(existing, request_digest) if existing

        result = create_revision!(context)
        response = {
          status: "draft_created",
          document_public_id: result.document.public_id,
          document_version_public_id: result.version.public_id,
          source_authority: result.document.source_authority,
          next_actions: %w[check_document_revision preview_document_publish]
        }
        McpMutationReceipt.create!(
          oauth_application: application,
          user:,
          document: result.document,
          document_version: result.version,
          operation: "apply_revision",
          idempotency_key_digest: key_digest,
          request_digest:,
          before_json: before_metadata(context[:document]),
          after_json: after_metadata(result.document, result.version),
          response_json: response,
          completed_at: Time.current
        )
      end
      response
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      raise ApplicationError::BadRequest, "確認tokenが無効または期限切れです"
    end

    private

    attr_reader :user, :application, :attributes

    def normalized
      @normalized ||= begin
        body_value = attributes.fetch("body").to_s
        raise ApplicationError::BadRequest, "本文を入力してください" if body_value.blank?
        raise ApplicationError::BadRequest, "本文は1MiB以内にしてください" if body_value.bytesize > BODY_MAX_BYTES
        body_value.encode!("UTF-8")

        document = attributes["document_public_id"].present? ? editable_document : nil
        source_path = if document
          document.latest_version&.source_relative_path.presence || attributes["source_path"]
        else
          attributes.fetch("source_path")
        end
        source_path = DocumentVersion.normalize_source_relative_path!(source_path)
        raise ApplicationError::BadRequest, "Markdown文書だけ改訂できます" unless File.extname(source_path).downcase.in?(DocumentVersion::MARKDOWN_EXTENSIONS)

        metadata = attributes.fetch("metadata", {}).to_h.deep_stringify_keys.slice(*METADATA_FIELDS)
        validate_metadata!(metadata, document:)

        {
          "document_public_id" => document&.public_id,
          "project_code" => document&.project&.code || attributes.fetch("project_code"),
          "slug" => document&.slug || attributes.fetch("slug"),
          "source_path" => source_path,
          "body" => body_value,
          "changelog_summary" => attributes["changelog_summary"].to_s.first(1_000),
          "metadata" => metadata
        }
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        raise ApplicationError::BadRequest, "本文はUTF-8で入力してください"
      end
    end

    def revision_context
      document = normalized["document_public_id"].present? ? editable_document : nil
      project = document&.project || Project.accessible_to(user).where(active: true).find_by!(code: normalized.fetch("project_code"))
      base_version = document&.latest_version
      { project:, document:, base_version: }
    end

    def editable_document
      @editable_document ||= begin
        document = Document.active_only.find_by!(public_id: attributes["document_public_id"])
        raise ApplicationError::Forbidden unless user.internal?
        raise ApplicationError::BadRequest, "この文書はdocs-portalが正本ではありません" unless document.source_authority_docs_portal?

        document
      end
    end

    def validate_metadata!(metadata, document:)
      model = document ? Document.find(document.id) : Document.new
      model.assign_attributes(metadata)
      model.title = attributes.dig("metadata", "title").presence || attributes["title"] if model.title.blank?
      model.slug = attributes["slug"] if model.slug.blank?
      model.category ||= :spec
      model.document_kind ||= :markdown
      model.visibility_policy ||= :internal_only
      model.importance_level ||= :normal
      model.recommended_sort_order ||= 100
      model.source_authority = :docs_portal
      model.valid?
      allowed_errors = document ? [] : [:project]
      messages = model.errors.reject { |error| allowed_errors.include?(error.attribute) }.map(&:full_message)
      raise ApplicationError::BadRequest, messages.to_sentence if messages.any?
    end

    def signed_payload(context)
      {
        user_public_id: user.public_id,
        application_uid: application.uid,
        project_public_id: context.fetch(:project).public_id,
        document_public_id: context[:document]&.public_id,
        document_updated_at: context[:document]&.updated_at&.iso8601(6),
        base_version_public_id: context[:base_version]&.public_id,
        base_version_updated_at: context[:base_version]&.updated_at&.iso8601(6),
        revision_digest: revision_digest
      }
    end

    def revision_digest
      @revision_digest ||= Digest::SHA256.hexdigest(canonical_json(normalized))
    end

    def body
      normalized.fetch("body")
    end

    def body_digest
      Digest::SHA256.hexdigest(body)
    end

    def secure_payload_match?(actual, expected)
      ActiveSupport::SecurityUtils.secure_compare(
        Digest::SHA256.hexdigest(canonical_json(actual)),
        Digest::SHA256.hexdigest(canonical_json(expected))
      )
    end

    def canonical_json(value)
      JSON.generate(canonicalize(value))
    end

    def canonicalize(value)
      case value
      when Hash
        value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { |item| canonicalize(item) }
      when Array
        value.map { |item| canonicalize(item) }
      else
        value
      end
    end

    def lock_and_verify_context!(context, signed)
      document = context[:document]
      if document
        document.lock!
        raise ApplicationError::BadRequest, "preview後に文書が変更されました" unless document.updated_at.iso8601(6) == signed[:document_updated_at]
        version = document.latest_version
        raise ApplicationError::BadRequest, "preview後に最新版が変更されました" unless version&.public_id == signed[:base_version_public_id]
        raise ApplicationError::BadRequest, "この文書はdocs-portalが正本ではありません" unless document.source_authority_docs_portal?
      else
        context.fetch(:project).lock!
        if context.fetch(:project).documents.exists?(slug: normalized.fetch("slug"))
          raise ApplicationError::BadRequest, "同じslugの文書が既に存在します"
        end
      end
    end

    def create_revision!(context)
      path = Pathname.new(normalized.fetch("source_path"))
      tempfile = Tempfile.new(["mcp-revision-", path.extname])
      tempfile.binmode
      tempfile.write(body)
      tempfile.rewind
      upload = ActionDispatch::Http::UploadedFile.new(
        tempfile:,
        filename: path.basename.to_s,
        type: "text/markdown"
      )
      result = ManualDocumentUpload.new(
        project: context.fetch(:project),
        actor: user,
        uploaded_file: upload,
        source_path: path.dirname.to_s == "." ? nil : path.dirname.to_s,
        target_document: context[:document]
      ).call
      result.document.update!(document_attributes(result.document, new_document: context[:document].nil?))
      result.version.update!(changelog_summary: normalized["changelog_summary"].presence || "MCP document revision")
      result
    ensure
      tempfile&.close!
    end

    def document_attributes(document, new_document:)
      metadata = normalized.fetch("metadata").symbolize_keys
      metadata[:title] = attributes["title"] if new_document && metadata[:title].blank?
      metadata[:slug] = normalized.fetch("slug") if new_document
      metadata[:source_authority] = :docs_portal
      metadata
    end

    def metadata_changes(document)
      before = before_metadata(document)
      candidate = before.merge(normalized.fetch("metadata"))
      candidate["title"] = attributes["title"] if document.nil? && candidate["title"].blank?
      candidate.select { |key, value| before[key] != value }
    end

    def before_metadata(document)
      return {} unless document

      document.attributes.slice(*METADATA_FIELDS)
    end

    def after_metadata(document, version)
      document.attributes.slice(*METADATA_FIELDS).merge(
        "document_public_id" => document.public_id,
        "document_version_public_id" => version.public_id,
        "status" => version.status,
        "body_sha256" => body_digest
      )
    end

    def verify_replay_identity!(signed)
      valid = signed[:user_public_id] == user.public_id &&
        signed[:application_uid] == application.uid &&
        signed[:revision_digest] == revision_digest
      raise ApplicationError::BadRequest, "確認内容が一致しません" unless valid
    end

    def validate_idempotency_key!(value)
      raise ApplicationError::BadRequest, "idempotency_keyは8〜200文字で指定してください" unless IDEMPOTENCY_KEY_RANGE.cover?(value.to_s.length)
    end

    def receipt_scope(operation, key_digest)
      McpMutationReceipt.where(
        oauth_application: application,
        user:,
        operation:,
        idempotency_key_digest: key_digest
      )
    end

    def replay(receipt, request_digest)
      raise ApplicationError::BadRequest, "idempotency_keyが異なる内容で使用されています" unless receipt.request_digest == request_digest

      receipt.response_json.deep_symbolize_keys
    end

    def verifier
      Rails.application.message_verifier(:mcp_document_revision)
    end

    def read_only_maintenance?
      ActiveModel::Type::Boolean.new.cast(ENV["READ_ONLY_MAINTENANCE"])
    end
  end
end
