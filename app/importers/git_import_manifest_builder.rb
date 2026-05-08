require "fileutils"

class GitImportManifestBuilder
  Result = Data.define(:artifact_root, :manifest_path, :manifest, :summary)

  def initialize(source:, worktree_path:, commit_sha:)
    @source = source
    @worktree_path = Pathname.new(worktree_path)
    @commit_sha = commit_sha
  end

  def call
    artifact_root = DocumentImporter::IMPORT_ROOT.join("git_pull", @source.public_id, @commit_sha)
    attachments_root = artifact_root.join("attachments")
    FileUtils.rm_rf(artifact_root)
    FileUtils.mkdir_p(attachments_root)

    documents = path_catalog.markdown_paths.map do
      document_payload_builder(attachments_root).call(_1)
    end
    deleted_candidates = deleted_candidates_for(documents)
    manifest = {
      source_repo: @source.repository_full_name,
      source_branch: @source.branch,
      source_commit_hash: @commit_sha,
      documents: documents
    }

    manifest_path = artifact_root.join("manifest.json")
    File.write(manifest_path, JSON.pretty_generate(manifest))

    Result.new(
      artifact_root: artifact_root,
      manifest_path: manifest_path,
      manifest: manifest,
      summary: {
        documents: documents.size,
        attachments: documents.sum { _1.fetch(:files).size },
        deleted_candidates: deleted_candidates,
        source_path: @source.normalized_source_path,
        commit_sha: @commit_sha
      }
    )
  end

  private

  def deleted_candidates_for(documents)
    project = @source.project
    return [] unless project && project.persisted?
    return [] unless @source.class.exists?(id: @source.id)

    imported_paths = documents.map { _1.fetch(:source_relative_path) }
    existing_paths = project.documents.includes(:latest_version).filter_map { _1.latest_version&.source_relative_path }
    existing_paths.grep(%r{\A#{Regexp.escape(@source.normalized_source_path)}/}).sort - imported_paths.sort
  end

  def path_catalog
    @path_catalog ||= GitImport::PathCatalog.new(worktree_path: @worktree_path)
  end

  def document_payload_builder(attachments_root)
    GitImport::DocumentPayloadBuilder.new(
      source: @source,
      worktree_path: @worktree_path,
      commit_sha: @commit_sha,
      attachments_root:,
      path_catalog:
    )
  end
end
