require "rails_helper"

RSpec.describe DocumentImporter do
  describe "#call" do
    it "persists source path metadata from the manifest" do
      import_root = Rails.root.join("tmp", "spec_imports", SecureRandom.hex(8))
      artifact_root = import_root.join("artifact")
      manifest_path = artifact_root.join("manifest.json")
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

    it "imports non-semver version labels as opaque document version labels" do
      import_root = Rails.root.join("tmp", "spec_imports", SecureRandom.hex(8))
      artifact_root = import_root.join("artifact")
      manifest_path = artifact_root.join("manifest.json")
      actor = create(:user, :internal)
      project = create(:project, code: "SRCOPAQUE")

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
              slug: "quarterly-plan",
              title: "四半期計画",
              category: "spec",
              document_kind: "markdown",
              visibility_policy: "restricted_external",
              version_label: "2026-Q2",
              status: "published",
              source_relative_path: "docs/quarterly-plan.md"
            },
            {
              project_code: project.code,
              slug: "client-review",
              title: "顧客レビュー",
              category: "manual",
              document_kind: "markdown",
              visibility_policy: "restricted_external",
              version_label: "client-a-draft",
              status: "draft",
              source_relative_path: "docs/client-review.md"
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

      published_document = Document.find_by!(slug: "quarterly-plan")
      draft_document = Document.find_by!(slug: "client-review")
      expect(published_document.document_versions.count).to eq(1)
      expect(draft_document.document_versions.count).to eq(1)

      published_version = published_document.document_versions.first
      draft_version = draft_document.document_versions.first

      expect(published_version.version_label).to eq("2026-Q2")
      expect(published_document.latest_version_id).to eq(published_version.id)
      expect(draft_version.version_label).to eq("client-a-draft")
      expect(draft_document.latest_version).to be_nil
    ensure
      FileUtils.rm_rf(import_root) if import_root
    end

    it "overwrites the existing latest version when version_label is omitted" do
      import_root = Rails.root.join("tmp", "spec_imports", SecureRandom.hex(8))
      artifact_root = import_root.join("artifact")
      manifest_path = artifact_root.join("manifest.json")
      actor = create(:user, :internal)
      project = create(:project, code: "SRCOVERWRITE")
      notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: true)

      document = create(
        :document,
        project: project,
        slug: "design-doc",
        title: "旧設計書",
        category: :manual,
        document_kind: :markdown,
        visibility_policy: :restricted_external
      )
      version = create(
        :document_version,
        document: document,
        version_label: "v1.0.0",
        status: :published,
        source_commit_hash: "old-commit",
        markdown_entry_path: "legacy-page",
        site_build_path: "legacy-page",
        pdf_snapshot_path: "legacy-page/manual.pdf"
      )
      version.assign_source_path_metadata!(source_path: "docs/design-doc.md", snapshot_kind: "editable_original")
      version.save!
      document.update!(latest_version: version)

      old_site_entry = version.site_root_absolute_path.join("legacy-page", "index.html")
      FileUtils.mkdir_p(old_site_entry.dirname)
      File.write(old_site_entry, "old html")

      old_attachment_path = Rails.root.join("storage", "document_files", "imports-spec", "old-manual.pdf")
      FileUtils.mkdir_p(old_attachment_path.dirname)
      File.write(old_attachment_path, "old attachment")
      old_file = create(
        :document_file,
        document_version: version,
        file_name: "old-manual.pdf",
        content_type: "application/pdf",
        storage_key: "imports-spec/old-manual.pdf",
        file_size: 14
      )

      FileUtils.mkdir_p(artifact_root.join("attachments", "imports-spec"))
      FileUtils.mkdir_p(artifact_root.join("docusaurus", "build", "updated-page"))
      File.write(artifact_root.join("attachments", "imports-spec", "new-manual.pdf"), "new attachment")
      File.write(artifact_root.join("docusaurus", "build", "updated-page", "index.html"), "new html")
      File.write(
        manifest_path,
        JSON.generate(
          source_repo: "example/docs",
          source_branch: "main",
          source_commit_hash: "new-commit",
          documents: [
            {
              project_code: project.code,
              slug: "design-doc",
              title: "新設計書",
              category: "spec",
              document_kind: "markdown",
              visibility_policy: "restricted_external",
              status: "published",
              source_relative_path: "docs/design-doc.md",
              snapshot_kind: "editable_original",
              markdown_entry_path: "updated-page",
              site_build_path: "updated-page",
              pdf_snapshot_path: "updated-page/manual.pdf",
              files: [
                {
                  file_name: "new-manual.pdf",
                  content_type: "application/pdf",
                  storage_key: "imports-spec/new-manual.pdf",
                  file_size: 14
                }
              ]
            }
          ]
        )
      )

      stub_const("DocumentImporter::IMPORT_ROOT", import_root)

      described_class.new(
        artifact_root: artifact_root.to_s,
        manifest_path: manifest_path.to_s,
        actor: actor,
        change_event_notifier: notifier
      ).call

      document.reload
      version.reload

      expect(document.title).to eq("新設計書")
      expect(document.category).to eq("spec")
      expect(document.latest_version_id).to eq(version.id)
      expect(document.document_versions.count).to eq(1)
      expect(version.version_label).to eq("v1.0.0")
      expect(version.source_commit_hash).to eq("new-commit")
      expect(version.site_build_path).to eq("updated-page")
      expect(version.pdf_snapshot_path).to eq("updated-page/manual.pdf")
      expect(version.source_relative_path).to eq("docs/design-doc.md")
      expect(version.document_files.pluck(:file_name, :storage_key)).to eq([["new-manual.pdf", "imports-spec/new-manual.pdf"]])
      expect(DocumentFile.exists?(old_file.id)).to eq(false)
      expect(old_attachment_path.exist?).to eq(false)
      expect(version.site_root_absolute_path.join("legacy-page", "index.html").exist?).to eq(false)
      expect(File.read(version.site_entry_absolute_path)).to eq("new html")
      expect(notifier).to have_received(:notify).with(
        file_events: [{ path: "docs/design-doc.md", operation: "update" }],
        event_source: "artifact_import",
        metadata: hash_including(source_commit_hash: "new-commit")
      )
    ensure
      FileUtils.rm_rf(import_root) if import_root
      FileUtils.rm_rf(version&.site_root_absolute_path)
      FileUtils.rm_f(old_attachment_path) if defined?(old_attachment_path) && old_attachment_path
      FileUtils.rm_f(Rails.root.join("storage", "document_files", "imports-spec", "new-manual.pdf"))
    end

    it "rejects duplicate opaque versioned imports for the same document" do
      import_root = Rails.root.join("tmp", "spec_imports", SecureRandom.hex(8))
      artifact_root = import_root.join("artifact")
      manifest_path = artifact_root.join("manifest.json")
      actor = create(:user, :internal)
      project = create(:project, code: "SRCDUP")
      document = create(:document, project: project, slug: "design-doc")
      version = create(:document_version, document: document, version_label: "2026-Q2", status: :published)
      version.assign_source_path_metadata!(source_path: "docs/design-doc.md")
      version.save!
      document.update!(latest_version: version)

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
              version_label: "2026-Q2",
              status: "published",
              source_relative_path: "docs/design-doc.md"
            }
          ]
        )
      )

      stub_const("DocumentImporter::IMPORT_ROOT", import_root)

      expect do
        described_class.new(
          artifact_root: artifact_root.to_s,
          manifest_path: manifest_path.to_s,
          actor: actor
        ).call
      end.to raise_error(ArgumentError, "Document version already exists: design-doc 2026-Q2")

      expect(document.reload.document_versions.count).to eq(1)
    ensure
      FileUtils.rm_rf(import_root) if import_root
    end
  end
end
