require "digest"

class ProjectsController < BaseController
  def index
    @projects = Project.accessible_to(current_user)
      .includes(:company, documents: :latest_version)
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

    @current_document = current_document_for_tree_refresh
    @tree_projects = portal_tree_projects(include_project: @project)
    @current_project = params[:tree_action] == "hide" && params[:source_path].blank? && @current_document.blank? ? nil : @project
    expanded_source_path = params[:tree_action] == "show" ? params[:source_path] : nil
    collapsed_source_path = params[:tree_action] == "hide" ? params[:source_path] : nil
    persist_document_tree_state!(expanded_source_path:, collapsed_source_path:)

    respond_to_document_tree(
      projects: @tree_projects,
      current_project: @current_project,
      current_document: @current_document,
      expanded_source_path:,
      collapsed_source_path:
    )
  end

  def document_tree_all
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @tree_projects = portal_tree_projects(include_project: @project)
    update_current_project_tree_expansion!(@project, action: params[:tree_action].to_s)

    respond_to_document_tree(projects: @tree_projects, current_project: @project)
  end

  def document_detail_tree
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)

    @documents = portal_documents_for(@project)
    expanded_keys = update_project_detail_tree_expansion!(@project, action: params[:tree_action].to_s, source_path: params[:source_path])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "project_document_detail_tree",
          partial: "projects/document_detail_tree",
          locals: { documents: @documents, expanded_keys: }
        )
      end
      format.html { redirect_to project_path(@project) }
    end
  end

  private

  def respond_to_document_tree(projects:, current_project: nil, current_document: nil, expanded_source_path: nil, collapsed_source_path: nil)
    tree_locals = {
      projects:,
      current_project:,
      current_document:,
      expanded_source_path:,
      collapsed_source_path:
    }
    toolbar_locals = {
      current_project:,
      current_document:
    }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("document_tree_panel", partial: "documents/tree", locals: tree_locals),
          turbo_stream.replace("document_tree_toolbar", partial: "documents/tree_toolbar", locals: toolbar_locals)
        ]
      end
      format.html { redirect_back fallback_location: projects_path }
    end
  end

  def current_document_for_tree_refresh
    return if params[:document_slug].blank?

    document = @project.documents.find_by!(slug: params[:document_slug])
    require_document_access!(document)
    return document if current_user.internal? || document.visible_in_portal_for?(current_user)

    raise ApplicationError::Forbidden
  end

  def persist_document_tree_state!(expanded_source_path:, collapsed_source_path:)
    return unless current_user.respond_to?(:tree_view_state_for)

    persisted_state = current_user.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    expanded_keys = Array(persisted_state.expanded_keys)
    toggled_key = document_tree_toggled_node_key(expanded_source_path:, collapsed_source_path:)
    return if toggled_key.blank?

    if params[:tree_action] == "show"
      expanded_keys |= [toggled_key]
    elsif params[:tree_action] == "hide"
      expanded_keys -= [toggled_key]
    end

    persist_document_tree_expanded_keys!(expanded_keys)
  end

  def update_current_project_tree_expansion!(project, action:)
    return unless current_user.respond_to?(:tree_view_state_for)

    persisted_state = current_user.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    expanded_keys = Array(persisted_state.expanded_keys)
    project_keys = document_tree_project_expanded_keys(project)

    case action
    when "show"
      expanded_keys |= project_keys
    when "hide"
      expanded_keys -= project_keys
    end

    persist_document_tree_expanded_keys!(expanded_keys)
  end

  def persist_document_tree_expanded_keys!(expanded_keys)
    return unless current_user.respond_to?(:save_tree_view_state!)

    current_user.save_tree_view_state!(
      DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY,
      expanded_keys:
    )
  end

  def update_project_detail_tree_expansion!(project, action:, source_path: nil)
    tree_instance_key = "documents:project_detail:#{project.id}"
    all_keys = project_detail_tree_folder_keys_for(project)
    persisted_state = current_user.respond_to?(:tree_view_state_for) ? current_user.tree_view_state_for(tree_instance_key) : nil
    expanded_keys = persisted_state ? Array(persisted_state.expanded_keys) : all_keys

    case action
    when "expand", "show"
      if source_path.present?
        expanded_keys |= [project_detail_tree_folder_key(project, source_path)]
      else
        expanded_keys = all_keys
      end
    when "collapse", "hide"
      if source_path.present?
        expanded_keys -= [project_detail_tree_folder_key(project, source_path)]
      else
        expanded_keys = []
      end
    end

    current_user.save_tree_view_state!(tree_instance_key, expanded_keys:) if current_user.respond_to?(:save_tree_view_state!)
    expanded_keys
  end

  def project_detail_tree_folder_keys_for(project)
    portal_documents_for(project).flat_map do |document|
      document_tree_folder_ancestor_paths(document_tree_document_source_directory(document)).map do |path|
        project_detail_tree_folder_key(project, path)
      end
    end.compact_blank.uniq
  end

  def project_detail_tree_folder_key(project, source_path)
    "project_detail_folder_#{project.id}_#{Digest::SHA256.hexdigest(source_path.to_s).first(16)}"
  end

  def document_tree_project_expanded_keys(project)
    ["project_#{project.id}", *document_tree_folder_keys_for(project)]
  end

  def document_tree_folder_keys_for(project)
    portal_documents_for(project).flat_map do |document|
      document_tree_folder_ancestor_paths(document_tree_document_source_directory(document)).map do |path|
        "folder_#{project.id}_#{Digest::SHA256.hexdigest(path).first(16)}"
      end
    end.compact_blank.uniq
  end

  def document_tree_document_source_directory(document)
    version = document.latest_version
    source_directory = version&.source_directory.to_s.tr("\\", "/").split("/").reject(&:blank?).join("/")
    return source_directory if source_directory.present?

    relative_path = version&.source_relative_path.to_s.tr("\\", "/").split("/").reject(&:blank?)
    relative_path.pop
    relative_path.join("/")
  end

  def document_tree_folder_ancestor_paths(source_path)
    segments = source_path.to_s.tr("\\", "/").split("/").reject(&:blank?)
    segments.each_index.map { |index| segments[0..index].join("/") }
  end

  def document_tree_toggled_node_key(expanded_source_path:, collapsed_source_path:)
    if expanded_source_path.present?
      "folder_#{@project.id}_#{Digest::SHA256.hexdigest(expanded_source_path).first(16)}"
    elsif collapsed_source_path.present?
      "folder_#{@project.id}_#{Digest::SHA256.hexdigest(collapsed_source_path).first(16)}"
    elsif params[:node_id].present?
      "project_#{params[:node_id]}"
    end
  end

  def portal_tree_projects(include_project: nil)
    projects = Project.accessible_to(current_user)
      .includes(:company, documents: :latest_version)
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
