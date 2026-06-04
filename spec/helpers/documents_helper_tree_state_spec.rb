require "rails_helper"

RSpec.describe DocumentsHelper, type: :helper do
  describe "#document_tree_initial_expansion_state" do
    let(:project) { instance_double(Project) }
    let(:current_document) { instance_double(Document, project:) }

    before do
      allow(helper).to receive(:document_tree_source_directory).with(current_document).and_return("guides/admin")
      allow(helper).to receive(:document_tree_folder_node_for) { |_project, path| "folder:#{path}" }
      allow(helper).to receive(:node_key) { |node| "key:#{node}" }
    end

    it "keeps the current document ancestors expanded when the current branch is collapsed" do
      state = helper.send(
        :document_tree_initial_expansion_state,
        current_project: project,
        current_document:,
        expanded_source_path: nil,
        collapsed_source_path: "guides"
      )

      expect(state.fetch(:expanded_keys)).to include("key:folder:guides", "key:folder:guides/admin")
      expect(state.fetch(:collapsed_keys)).not_to include("key:folder:guides")
    end

    it "still collapses a sibling branch while keeping the current document path visible" do
      state = helper.send(
        :document_tree_initial_expansion_state,
        current_project: project,
        current_document:,
        expanded_source_path: nil,
        collapsed_source_path: "release-notes"
      )

      expect(state.fetch(:expanded_keys)).to include("key:folder:guides", "key:folder:guides/admin")
      expect(state.fetch(:expanded_keys)).not_to include("key:folder:release-notes")
      expect(state.fetch(:collapsed_keys)).to include("key:folder:release-notes")
    end
  end
end
