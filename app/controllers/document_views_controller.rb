class DocumentViewsController < BaseController
  def show
    version = DocumentVersion.find_by!(public_id: params[:public_id])
    require_document_version_view_access!(version)

    unless version.rendered_site_available?
      render plain: "Rendered HTML is not available for this version. Run import/build first.", status: :not_found
      return
    end

    redirect_to project_site_path(version.document.project, site_path: version.html_view_site_path, version_id: version.public_id)
  end
end
