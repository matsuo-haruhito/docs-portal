class AccessRequestDecider
  PROJECT_ROLE_BY_ACCESS_LEVEL = {
    "view" => "viewer",
    "download" => "viewer",
    "manage" => "editor"
  }.freeze

  DOCUMENT_ACCESS_LEVEL_BY_REQUEST = {
    "view" => "view",
    "download" => "download",
    "manage" => "download"
  }.freeze

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
    case access_request.requestable
    when Project
      grant_project_access!(access_request.requestable)
    when Document
      grant_document_access!(access_request.requestable)
    when DocumentFile
      grant_document_access!(access_request.requestable.document_version.document)
    end
  end

  def grant_project_access!(project)
    membership = ProjectMembership.find_or_initialize_by(
      project:,
      user: access_request.requester
    )
    membership.role = max_project_role(membership.role, PROJECT_ROLE_BY_ACCESS_LEVEL.fetch(access_request.requested_access_level))
    membership.save!
  end

  def grant_document_access!(document)
    company = access_request.requester.company

    raise ActiveRecord::RecordInvalid, access_request if company.blank?

    ProjectMembership.find_or_create_by!(project: document.project, user: access_request.requester)

    permission = DocumentPermission.find_or_initialize_by(document:, company:)
    permission.access_level = max_document_access_level(
      permission.access_level,
      DOCUMENT_ACCESS_LEVEL_BY_REQUEST.fetch(access_request.requested_access_level)
    )
    permission.save!
  end

  def max_project_role(current, requested)
    values = ProjectMembership.roles
    values.key([values.fetch(current), values.fetch(requested)].max)
  end

  def max_document_access_level(current, requested)
    values = DocumentPermission.access_levels
    values.key([values.fetch(current), values.fetch(requested)].max)
  end
end
