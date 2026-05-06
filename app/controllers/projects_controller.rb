class ProjectsController < BaseController
  def index
    @projects = portal_tree_projects
  end

  def show
    @project = Project.find_by!(code: params[:code])
    require_project_access!(@project)
    @documents = portal_documents_for(@project)
    @important_documents = @documents.select { %w[critical important].include?(_1.importance_level) }
    @tree_projects = portal_tree_projects(include_project: @project)
  end

  private

  def portal_tree_projects(include_project: nil)
    projects = Project.accessible_to(current_user)
      .includes(documents: :latest_version)
      .order(:code)
    return projects if current_user.internal?

    visible_projects = projects.select { portal_documents_for(_1).any? || _1.documents.empty? }
    visible_projects << include_project if include_project.present? && visible_projects.exclude?(include_project)
    visible_projects
  end

  def portal_documents_for(project)
    documents = project.documents.accessible_to(current_user).includes(:latest_version).recommended_first
    return documents if current_user.internal?

    documents.select { externally_portal_visible_document?(_1) }
  end

  def externally_portal_visible_document?(document)
    return false unless document.visible_in_portal_for?(current_user)
    return true unless document.document_versions.exists?

    latest_version = document.latest_version
    latest_version.present? && latest_version.viewable_by?(current_user)
  end
end
