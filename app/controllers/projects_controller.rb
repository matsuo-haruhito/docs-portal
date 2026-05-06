class ProjectsController < BaseController
  def index
    @projects = Project.accessible_to(current_user)
      .includes(documents: :latest_version)
      .order(:code)
    @projects = @projects.select { project_list_visible_for_portal?(_1) } unless current_user.internal?
  end

  def show
    @project = Project.find_by!(code: params[:code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @documents = portal_documents_for(@project)
    @important_documents = @documents.select { %w[critical important].include?(_1.importance_level) }
    @tree_projects = portal_tree_projects(include_project: @project)
  end

  def document_tree
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @tree_projects = portal_tree_projects(include_project: @project)
    @current_project = params[:tree_action] == "hide" ? nil : @project

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "document_tree_panel",
          partial: "documents/tree",
          locals: {
            projects: @tree_projects,
            current_project: @current_project,
            current_document: nil
          }
        )
      end
      format.html { redirect_to project_path(@project) }
    end
  end

  private

  def portal_tree_projects(include_project: nil)
    projects = Project.accessible_to(current_user)
      .includes(documents: :latest_version)
      .order(:code)
    return projects if current_user.internal?

    visible_projects = projects.select { portal_documents_for(_1).any? }
    visible_projects << include_project if include_project.present? && visible_projects.exclude?(include_project)
    visible_projects
  end

  def project_list_visible_for_portal?(project)
    project.documents.empty? || portal_documents_for(project).any?
  end

  def portal_documents_for(project)
    documents = project.documents.accessible_to(current_user).includes(:latest_version).recommended_first
    return documents if current_user.internal?

    documents.select { externally_portal_visible_document?(_1) }
  end

  def externally_portal_visible_document?(document)
    return false unless document.visible_in_portal_for?(current_user)
    return true unless document.document_versions.exists?

    document.document_versions.published.any? { _1.within_publication_window? }
  end
end
