require "digest"

module GitImport
  class DocumentPayloadBuilder
    def initialize(source:, worktree_path:, commit_sha:, attachments_root:, path_catalog:)
      @source = source
      @worktree_path = Pathname(worktree_path)
      @commit_sha = commit_sha
      @attachments_root = Pathname(attachments_root)
      @path_catalog = path_catalog
    end

    def call(markdown_path)
      relative_path = markdown_path.relative_path_from(worktree_path).to_s
      files = path_catalog.attachment_paths_for(markdown_path).map { copy_attachment(_1) }
      markdown_file = copy_attachment(markdown_path)

      {
        project_code: source.project.code,
        slug: slug_for(relative_path),
        title: title_for(markdown_path),
        category: "spec",
        document_kind: "markdown",
        visibility_policy: "restricted_external",
        version_label: version_label,
        status: "published",
        source_relative_path: File.join(source.normalized_source_path, relative_path),
        snapshot_kind: "git_import",
        changelog_summary: "Imported from #{source.repository_full_name}@#{commit_sha.first(12)}",
        files: [markdown_file, *files]
      }
    end

    private

    attr_reader :source, :worktree_path, :commit_sha, :attachments_root, :path_catalog

    def copy_attachment(path)
      relative_path = path.relative_path_from(worktree_path).to_s
      storage_key = File.join("git_imports", source.public_id, commit_sha, relative_path)
      destination = attachments_root.join(storage_key)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(path, destination)

      {
        file_name: relative_path,
        content_type: path_catalog.content_type_for(path),
        storage_key: storage_key,
        file_size: path.size
      }
    end

    def title_for(markdown_path)
      first_heading = File.foreach(markdown_path.to_s).lazy.map(&:strip).find { _1.start_with?("# ") }
      first_heading&.delete_prefix("# ")&.presence || markdown_path.basename(markdown_path.extname).to_s
    end

    def slug_for(relative_path)
      base = relative_path.sub(%r{/(README|index)\.(md|mdx)\z}i, "").sub(/\.(md|mdx)\z/i, "")
      base = "index" if base.blank? || base == relative_path
      parameterized = base.tr("/", "-").parameterize
      parameterized.presence || Digest::SHA256.hexdigest(relative_path).first(16)
    end

    def version_label
      "git-#{commit_sha.first(12)}"
    end
  end
end
