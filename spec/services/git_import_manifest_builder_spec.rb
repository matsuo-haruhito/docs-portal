require "rails_helper"

RSpec.describe GitImportManifestBuilder do
  describe "#call" do
    it "builds a DocumentImporter manifest from markdown and sibling attachments" do
      import_root = Rails.root.join("tmp", "spec_git_imports", SecureRandom.hex(8))
      worktree_path = import_root.join("worktree")
      source_path = worktree_path.join("docs")
      project = create(:project, code: "GIT")
      source = create(
        :git_import_source,
        project: project,
        public_id: "gis_test",
        repository_full_name: "example/docs",
        branch: "main",
        source_path: "docs"
      )

      FileUtils.mkdir_p(source_path.join("guide"))
      File.write(source_path.join("guide", "README.md"), "# Guide\n\nbody")
      File.write(source_path.join("guide", "flow.mmd"), "graph TD; A-->B")
      File.write(source_path.join("guide", "image.png"), "png")

      stub_const("DocumentImporter::IMPORT_ROOT", import_root.join("imports"))
      FileUtils.mkdir_p(DocumentImporter::IMPORT_ROOT)

      result = described_class.new(
        source: source,
        worktree_path: source_path,
        commit_sha: "abc123def4567890"
      ).call

      expect(result.manifest[:source_repo]).to eq("example/docs")
      expect(result.manifest[:source_branch]).to eq("main")
      expect(result.manifest[:source_commit_hash]).to eq("abc123def4567890")
      expect(result.manifest[:documents].size).to eq(1)

      document = result.manifest[:documents].first
      expect(document[:project_code]).to eq("GIT")
      expect(document[:slug]).to eq("guide")
      expect(document[:title]).to eq("Guide")
      expect(document[:source_relative_path]).to eq("docs/guide/README.md")
      expect(document[:snapshot_kind]).to eq("git_import")
      expect(document[:version_label]).to eq("git-abc123def456")
      expect(document[:files].map { _1[:file_name] }).to contain_exactly("guide/README.md", "guide/flow.mmd", "guide/image.png")
      expect(result.summary[:documents]).to eq(1)
      expect(result.summary[:attachments]).to eq(3)
      expect(result.manifest_path.exist?).to be(true)
    ensure
      FileUtils.rm_rf(import_root) if import_root
    end
  end
end
