require "rails_helper"
require "digest"

RSpec.describe "Project document tree state", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "TREESTATE", name: "Tree State Project") }

  def create_document_with_source(project:, title:, slug:, source_relative_path:)
    document = create(:document, project:, title:, slug:)
    version = create(:document_version, document:, source_relative_path:)
    document.update!(latest_version: version)
    document
  end

  def sidebar_state
    TreeViewState.find_by!(owner: user, tree_instance_key: DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
  end

  def detail_state(project)
    TreeViewState.find_by!(owner: user, tree_instance_key: "documents:project_detail:#{project.id}")
  end

  def folder_key(project, source_path)
    "folder_#{project.id}_#{Digest::SHA256.hexdigest(source_path).first(16)}"
  end

  def project_key(project)
    "project_#{project.id}"
  end

  def detail_folder_key(project, source_path)
    "project_detail_folder_#{project.id}_#{Digest::SHA256.hexdigest(source_path).first(16)}"
  end

  before do
    sign_in_as(user)
  end

  it "persists left-pane folder show and hide actions while replacing the tree panel" do
    create_document_with_source(
      project:,
      title: "Install Guide",
      slug: "install-guide",
      source_relative_path: "guides/install/README.md"
    )

    get project_document_tree_path(project, format: :turbo_stream), params: {
      tree_action: "show",
      source_path: "guides/install"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="document_tree_panel"')
    expect(response.body).to include('target="document_tree_toolbar"')
    expect(sidebar_state.expanded_keys).to include(folder_key(project, "guides/install"))

    get project_document_tree_path(project, format: :turbo_stream), params: {
      tree_action: "hide",
      source_path: "guides/install"
    }

    expect(response).to have_http_status(:ok)
    expect(sidebar_state.reload.expanded_keys).not_to include(folder_key(project, "guides/install"))
  end

  it "expands and collapses only the current project's sidebar keys" do
    other_project = create(:project, code: "OTHERTREE", name: "Other Tree Project")
    create_document_with_source(
      project:,
      title: "Main Guide",
      slug: "main-guide",
      source_relative_path: "guides/main/README.md"
    )
    create_document_with_source(
      project: other_project,
      title: "Other Guide",
      slug: "other-guide",
      source_relative_path: "other/main/README.md"
    )

    post document_tree_all_project_path(project, format: :turbo_stream), params: { tree_action: "show" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="document_tree_panel"')
    expect(response.body).to include('target="document_tree_toolbar"')
    expect(sidebar_state.expanded_keys).to include(
      project_key(project),
      folder_key(project, "guides"),
      folder_key(project, "guides/main")
    )
    expect(sidebar_state.expanded_keys).not_to include(project_key(other_project), folder_key(other_project, "other"))

    user.save_tree_view_state!(
      DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY,
      expanded_keys: [
        project_key(project),
        folder_key(project, "guides"),
        folder_key(project, "guides/main"),
        project_key(other_project),
        folder_key(other_project, "other")
      ]
    )

    post document_tree_all_project_path(project, format: :turbo_stream), params: { tree_action: "hide" }

    expect(response).to have_http_status(:ok)
    expect(sidebar_state.reload.expanded_keys).not_to include(
      project_key(project),
      folder_key(project, "guides"),
      folder_key(project, "guides/main")
    )
    expect(sidebar_state.expanded_keys).to include(project_key(other_project), folder_key(other_project, "other"))
  end

  it "stores project detail tree expansion under a separate instance key" do
    create_document_with_source(
      project:,
      title: "Detail Guide",
      slug: "detail-guide",
      source_relative_path: "guides/detail/README.md"
    )

    post document_detail_tree_project_path(project, format: :turbo_stream), params: {
      tree_action: "show",
      source_path: "guides/detail"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="project_document_detail_tree"')
    expect(detail_state(project).expanded_keys).to include(detail_folder_key(project, "guides/detail"))
    expect(TreeViewState.find_by(owner: user, tree_instance_key: DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)).to be_nil
  end
end
