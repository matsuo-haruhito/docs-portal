class AccessRequestDecider
  def initialize(access_request:, approver:)
    @access_request = access_request
    @approver = approver
  end

  def approve!
    validate_approver!
    raise ActiveRecord::RecordInvalid, access_request unless access_request.pending?

    AccessRequest.transaction do
      grant_access!
      access_request.update!(status: :approved, approver:, approved_at: Time.current)
    end

    access_request
  end

  def reject!(reason:)
    validate_approver!
    raise ActiveRecord::RecordInvalid, access_request unless access_request.pending?

    access_request.update!(
      status: :rejected,
      approver:,
      rejected_at: Time.current,
      rejection_reason: reason
    )

    access_request
  end

  private

  attr_reader :access_request, :approver

  def validate_approver!
    raise ActiveRecord::RecordNotFound, "Approver not found" unless approver&.internal?
  end

  def grant_access!
    if access_request.project.present?
      grant_project_access!
    elsif access_request.document.present?
      grant_document_access!
    end
  end

  def grant_project_access!
    ProjectMembership.find_or_create_by!(
      project: access_request.project,
      user: access_request.requester
    )
  end

  def grant_document_access!
    document = access_request.document
    company = access_request.requester.company

    raise ActiveRecord::RecordInvalid, access_request if company.blank?

    ProjectMembership.find_or_create_by!(project: document.project, user: access_request.requester)

    permission = DocumentPermission.find_or_initialize_by(document:, company:)
    permission.access_level = max_access_level(permission.access_level, access_request.requested_access_level)
    permission.save!
  end

  def max_access_level(current, requested)
    values = DocumentPermission.access_levels
    values.key([values.fetch(current), values.fetch(requested)].max)
  end
end
