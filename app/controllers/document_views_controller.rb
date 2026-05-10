class DocumentViewsController < BaseController
  def show
    version = DocumentVersion.find_by!(public_id: params[:public_id])
    require_document_version_view_access!(version)

    unless version.embedded_view_available?
      render plain: "Browser-viewable document body is not available for this version.", status: :not_found
      return
    end

    redirect_to project_document_path(
      version.document.project,
      version.document.slug,
      version_id: version.public_id,
      site_path: version.html_view_site_path
    )
  end
end
