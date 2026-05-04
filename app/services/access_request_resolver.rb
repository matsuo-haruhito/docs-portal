class AccessRequestResolver
  Result = Data.define(:access_request, :granted_record) do
    def granted?
      granted_record.present?
    end
  end

  def initialize(access_request:, approver:)
    @access_request = access_request
    @approver = approver
  end

  def approve!
    raise ApplicationError::Forbidden, "approver must be internal" unless approver&.internal?
    raise ApplicationError::BadRequest, "access request is not pending" unless access_request.pending?

    granted_record = nil

    AccessRequest.transaction do
      granted_record = grant_access!
      access_request.update!(
        approver:,
        status: :approved,
        approved_at: Time.current,
        rejected_at: nil,
        rejection_reason: nil,
        cancelled_at: nil
      )
    end

    Result.new(access_request:, granted_record:)
  end

  def reject!(reason:)
    raise ApplicationError::Forbidden, "approver must be internal" unless approver&.internal?
    raise ApplicationError::BadRequest, "access request is not pending" unless access_request.pending?

    access_request.update!(
      approver:,
      status: :rejected,
      rejected_at: Time.current,
      rejection_reason: reason,
      approved_at: nil,
      cancelled_at: nil
    )

    Result.new(access_request:, granted_record: nil)
  end

  def cancel!
    raise ApplicationError::BadRequest, "access request is not pending" unless access_request.pending?

    access_request.update!(status: :cancelled, cancelled_at: Time.current)
    Result.new(access_request:, granted_record: nil)
  end

  private

  attr_reader :access_request, :approver

  def grant_access!
    case access_request.requestable
    when Project
      ProjectMembership.find_or_create_by!(project: access_request.requestable, user: access_request.requester) do |membership|
        membership.role = :viewer
      end
    when Document
      grant_document_permission!(access_request.requestable)
    when DocumentFile
      grant_document_permission!(access_request.requestable.document_version.document)
    else
      raise ApplicationError::BadRequest, "unsupported requestable type"
    end
  end

  def grant_document_permission!(document)
    DocumentPermission.find_or_initialize_by(document:, user: access_request.requester).tap do |permission|
      permission.access_level = access_request.download? ? :download : :view
      permission.save!
    end
  end
end
