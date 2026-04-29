class DocumentViewsController < BaseController
  def show
    version = DocumentVersion.find(params[:id])
    authorize version, :show?
    entry_path = version.site_entry_absolute_path

    if version.site_build_path.blank? || entry_path.blank? || !File.exist?(entry_path)
      render plain: "Rendered HTML not found", status: :not_found
      return
    end

    redirect_to site_document_version_path(version, site_path: version.site_build_path)
  end
end
