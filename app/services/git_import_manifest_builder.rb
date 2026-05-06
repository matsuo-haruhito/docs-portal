require "digest"
require "fileutils"

class GitImportManifestBuilder
  MARKDOWN_EXTENSIONS = %w[.md .mdx].freeze
  DIAGRAM_EXTENSIONS = %w[.mmd .mermaid .puml .plantuml .d2].freeze

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

    documents = markdown_paths.map { build_document_payload(_1, attachments_root) }
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

  def markdown_paths
    Dir.glob(@worktree_path.join("**", "*").to_s).map { Pathname.new(_1) }.select do |path|
      path.file? && MARKDOWN_EXTENSIONS.include?(path.extname.downcase)
    end.sort
  end

  def build_document_payload(markdown_path, attachments_root)
    relative_path = markdown_path.relative_path_from(@worktree_path).to_s
    slug = slug_for(relative_path)
    version_label = "git-#{@commit_sha.first(12)}"
    files = attachment_paths_for(markdown_path).map { copy_attachment(_1, attachments_root) }
    markdown_file = copy_attachment(markdown_path, attachments_root)

    {
      project_code: @source.project.code,
      slug: slug,
      title: title_for(markdown_path),
      category: "spec",
      document_kind: "markdown",
      visibility_policy: "restricted_external",
      version_label: version_label,
      status: "published",
      source_relative_path: File.join(@source.normalized_source_path, relative_path),
      snapshot_kind: "git_import",
      changelog_summary: "Imported from #{@source.repository_full_name}@#{@commit_sha.first(12)}",
      files: [markdown_file, *files]
    }
  end

  def attachment_paths_for(markdown_path)
    sibling_files = markdown_path.dirname.children.select(&:file?)
    sibling_files.reject do |path|
      path == markdown_path || MARKDOWN_EXTENSIONS.include?(path.extname.downcase)
    end.select do |path|
      DIAGRAM_EXTENSIONS.include?(path.extname.downcase) || !path.basename.to_s.start_with?(".")
    end.sort
  end

  def copy_attachment(path, attachments_root)
    relative_path = path.relative_path_from(@worktree_path).to_s
    storage_key = File.join("git_imports", @source.public_id, @commit_sha, relative_path)
    destination = attachments_root.join(storage_key)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp(path, destination)

    {
      file_name: path.basename.to_s,
      content_type: content_type_for(path),
      storage_key: storage_key,
      file_size: path.size
    }
  end

  def content_type_for(path)
    case path.extname.downcase
    when ".md", ".mdx"
      "text/markdown"
    when ".png"
      "image/png"
    when ".jpg", ".jpeg"
      "image/jpeg"
    when ".gif"
      "image/gif"
    when ".svg"
      "image/svg+xml"
    when ".pdf"
      "application/pdf"
    else
      "application/octet-stream"
    end
  end

  def title_for(markdown_path)
    first_heading = File.foreach(markdown_path).lazy.map(&:strip).find { _1.start_with?("# ") }
    first_heading&.delete_prefix("# ")&.presence || markdown_path.basename(markdown_path.extname).to_s
  end

  def slug_for(relative_path)
    base = relative_path.sub(%r{/(README|index)\.(md|mdx)\z}i, "").sub(/\.(md|mdx)\z/i, "")
    base = "index" if base.blank? || base == relative_path
    parameterized = base.tr("/", "-").parameterize
    parameterized.presence || Digest::SHA256.hexdigest(relative_path).first(16)
  end

  def deleted_candidates_for(documents)
    imported_paths = documents.map { _1.fetch(:source_relative_path) }
    existing_paths = @source.project.documents.includes(:latest_version).filter_map { _1.latest_version&.source_relative_path }
    existing_paths.grep(%r{\A#{Regexp.escape(@source.normalized_source_path)}/}).sort - imported_paths.sort
  end
end
