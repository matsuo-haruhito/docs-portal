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

  def require_document_version_view_access!(version)
    raise ApplicationError::Forbidden unless version.viewable_by?(current_user)
  end

  def require_document_file_download_access!(document_file)
    raise ApplicationError::Forbidden unless document_file.downloadable_by?(current_user)
  end
end
