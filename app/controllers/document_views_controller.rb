class DocumentViewsController < BaseController
  def show
    version = DocumentVersion.find(params[:id])
    authorize version, :show?

    unless version.rendered_site_available?
      render plain: "Rendered HTML is not available for this version. Run import/build first.", status: :not_found
      return
    end

    redirect_to site_document_version_path(version, site_path: version.site_build_path)
  end
end
