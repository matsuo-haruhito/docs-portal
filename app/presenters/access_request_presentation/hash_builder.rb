module AccessRequestPresentation
  class HashBuilder
    def initialize(access_request:)
      @access_request = access_request
    end

    def call
      {
        public_id: access_request.public_id,
        status: access_request.status,
        status_label: access_request_status_label,
        requested_access_level: access_request.requested_access_level,
        requested_access_level_label: requested_access_level_label,
        reason: access_request.reason,
        rejection_reason: access_request.rejection_reason,
        requester: user_hash(access_request.requester),
        approver: user_hash(access_request.approver),
        requestable: requestable_hash,
        approved_at: access_request.approved_at&.iso8601,
        rejected_at: access_request.rejected_at&.iso8601,
        cancelled_at: access_request.cancelled_at&.iso8601,
        expires_at: access_request.expires_at&.iso8601,
        created_at: access_request.created_at&.iso8601
      }
    end

    private

    attr_reader :access_request

    def user_hash(user)
      return nil if user.blank?

      {
        public_id: user.public_id,
        name: user.name,
        email_address: user.email_address,
        user_type: user.user_type,
        company_id: user.company&.public_id
      }
    end

    def requestable_hash
      target = access_request.requestable
      base = {
        type: target.class.name,
        type_label: requestable_type_label(target),
        public_id: target.public_id
      }

      case target
      when Project
        base.merge(code: target.code, name: target.name)
      when Document
        base.merge(title: target.title, slug: target.slug, project_code: target.project.code)
      when DocumentFile
        document = target.document_version.document
        base.merge(file_name: target.file_name, document_id: document.public_id, document_title: document.title)
      else
        base
      end
    end

    def requested_access_level_label
      I18n.t(
        "labels.document_permissions.access_level.#{access_request.requested_access_level}",
        default: access_request.requested_access_level.to_s
      )
    end

    def access_request_status_label
      I18n.t("labels.access_requests.status.#{access_request.status}", default: access_request.status.to_s)
    end

    def requestable_type_label(target)
      I18n.t("labels.access_requests.requestable_type.#{target.model_name.singular}", default: target.class.name)
    end
  end
end
