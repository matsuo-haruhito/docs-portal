class BaseController < ApplicationController
  def redirect_to_back(**options)
    redirect_back fallback_location: root_path, **options
  end

  private

  def require_project_access!(project)
    raise ApplicationError::Forbidden unless project.viewable_by?(current_user)
  end

  def require_document_access!(document)
    raise ApplicationError::Forbidden unless document.viewable_by?(current_user)
  end

  def require_document_download_access!(document)
    raise ApplicationError::Forbidden unless document.downloadable_by?(current_user)
  end

  def require_document_version_view_access!(version)
    raise ApplicationError::Forbidden unless version.viewable_by?(current_user)
  end

  def require_document_file_download_access!(document_file)
    raise ApplicationError::Forbidden unless document_file.downloadable_by?(current_user)
  end

  def require_consent!(target:, timing: :first_view)
    result = ConsentRequirementChecker.new(user: current_user, target:, timing:).call
    return false if result.satisfied?

    redirect_to new_consent_path(
      target_type: result.target.class.name,
      target_public_id: consent_target_public_id(result.target),
      timing:,
      return_to: request.fullpath
    ), alert: "利用前に注意事項への同意が必要です。"
    true
  end

  def consent_target_public_id(target)
    return target.public_id if target.respond_to?(:public_id)
    return target.code if target.is_a?(Project)

    target.to_param
  end

  def record_view_access_log(site_path, version)
    record_access_log_safely(
      action_type: :view,
      target_type: "page",
      target_name: site_path.to_s,
      version:
    )
  end

  def record_download_access_log(document_file)
    version = document_file.document_version

    record_access_log_safely(
      action_type: :download,
      target_type: "file",
      target_name: document_file.file_name,
      version:
    )
  end

  def record_zip_download_access_log(version, target_name)
    record_access_log_safely(
      action_type: :download,
      target_type: "zip",
      target_name:,
      version:
    )
  end

  def record_access_log_safely(action_type:, target_type:, target_name:, version:)
    record_access_log!(
      action_type:,
      target_type:,
      target_name:,
      version:
    )
  rescue StandardError => e
    Rails.logger.error("AccessLog skipped: #{e.class}: #{e.message}")
  end

  def record_access_log!(action_type:, target_type:, target_name:, version:)
    AccessLog.create!(
      user: current_user,
      company: current_user.company,
      project: version.document.project,
      document: version.document,
      document_version: version,
      action_type:,
      target_type:,
      target_name:,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  end
end
