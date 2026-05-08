module ZipImport
  class ManifestBuilder
    def initialize(scan_result:, extracted_root:, artifact_root:, project:, source_repo:, source_branch:, source_commit_hash:, version_label:, status:, staging_key:)
      @scan_result = scan_result
      @extracted_root = Pathname(extracted_root)
      @artifact_root = Pathname(artifact_root)
      @project = project
      @source_repo = source_repo
      @source_branch = source_branch
      @source_commit_hash = source_commit_hash
      @version_label = version_label
      @status = status
      @staging_key = staging_key
      @path_classifier = PathClassifier.new(root: extracted_root)
    end

    def call
      {
        "source_repo" => source_repo,
        "source_branch" => source_branch,
        "source_commit_hash" => source_commit_hash,
        "documents" => scan_result.documents.map { manifest_document_for(_1) },
        "zip_import_preview" => {
          "orphan_files" => scan_result.orphan_files,
          "skipped_files" => scan_result.skipped_files,
          "warnings" => scan_result.warnings
        }
      }
    end

    private

    attr_reader :scan_result, :extracted_root, :artifact_root, :project, :source_repo, :source_branch, :source_commit_hash, :version_label, :status, :staging_key, :path_classifier

    def manifest_document_for(candidate)
      classification = DocumentClassificationSuggester.new.suggest(
        source_path: candidate.logical_path,
        file_name: File.basename(candidate.logical_path),
        frontmatter: candidate.frontmatter
      )

      {
        "project_code" => project.code,
        "slug" => candidate.slug,
        "title" => candidate.title,
        "category" => classification.attributes[:category] || "spec",
        "document_kind" => classification.attributes[:document_kind] || candidate.document_kind,
        "visibility_policy" => classification.attributes[:visibility_policy] || "restricted_external",
        "version_label" => version_label,
        "status" => status,
        "source_relative_path" => candidate.logical_path,
        "snapshot_kind" => classification.attributes[:snapshot_kind],
        "files" => candidate.attachment_paths.each_with_index.map { |path, index| manifest_file_for(candidate, path, index) }
      }.compact
    end

    def manifest_file_for(candidate, path, index)
      logical_path = path.relative_path_from(extracted_root).to_s.tr("\\", "/")
      storage_key = File.join(
        "zip_uploads",
        staging_key,
        candidate.slug,
        version_label,
        logical_path
      )
      destination = artifact_root.join("attachments", storage_key)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(path, destination)

      {
        "file_name" => logical_path,
        "content_type" => path_classifier.content_type_for(path),
        "storage_key" => storage_key,
        "file_size" => path.size,
        "sort_order" => index
      }
    end
  end
end
