require "rails_helper"

RSpec.describe DocumentImporter do
  describe "#call" do
    it "persists source path metadata from the manifest" do
      import_root = Rails.root.join("tmp", "spec_imports", SecureRandom.hex(8))
      artifact_root = import_root.join("artifact")
      manifest_path = import_root.join("manifest.json")
      actor = create(:user, :internal)
      project = create(:project, code: "SRC")

      FileUtils.mkdir_p(artifact_root)
      File.write(
        manifest_path,
        JSON.generate(
          source_repo: "example/docs",
          source_branch: "main",
          source_commit_hash: "abc123",
          documents: [
            {
              project_code: project.code,
              slug: "design-doc",
              title: "設計書",
              category: "spec",
              document_kind: "markdown",
              visibility_policy: "restricted_external",
              version_label: "v1",
              status: "published",
              source_relative_path: "作成資料\\編集正本\\設計書.md",
              snapshot_kind: "editable_original"
            }
          ]
        )
      )

      stub_const("DocumentImporter::IMPORT_ROOT", import_root)

      described_class.new(
        artifact_root: artifact_root.to_s,
        manifest_path: manifest_path.to_s,
        actor: actor
      ).call

      version = Document.find_by!(slug: "design-doc").latest_version
      expect(version.source_relative_path).to eq("作成資料/編集正本/設計書.md")
      expect(version.source_directory).to eq("作成資料/編集正本")
      expect(version.source_file_name).to eq("設計書.md")
      expect(version.source_basename).to eq("設計書")
      expect(version.source_extension).to eq("md")
      expect(version.snapshot_kind).to eq("editable_original")
    ensure
      FileUtils.rm_rf(import_root) if import_root
    end
  end
end
