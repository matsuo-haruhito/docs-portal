module Admin::BoundedProjectOptions
  extend ActiveSupport::Concern

  PROJECT_SELECT_OPTION_LIMIT = 100

  private

  def bounded_project_options(selected_project)
    projects = Project.order(:name, :id).limit(PROJECT_SELECT_OPTION_LIMIT).to_a
    return projects unless selected_project
    return projects if projects.any? { _1.id == selected_project.id }

    (projects + [selected_project]).sort_by { |project| [project.name.to_s, project.id] }
  end
end
