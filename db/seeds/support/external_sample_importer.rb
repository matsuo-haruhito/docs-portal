module SeedSupport
  class ExternalSampleImporter
    def initialize(context)
      @context = context
    end

    def documents(root)
      return [] unless root&.directory?

      child_directories(root).flat_map do |sample_set_dir|
        site_dirs = child_directories(sample_set_dir)
        site_dirs = [sample_set_dir] if site_dirs.empty?

        site_dirs.flat_map do |site_dir|
          sample_set_key = sample_set_dir.basename.to_s
          project_name = site_dirs == [sample_set_dir] ? sample_set_key : "#{sample_set_key} / #{site_dir.basename}"
          project_code = project_code_for_sample_set(project_name)
          snapshot_dirs = child_directories(site_dir).select { version_snapshot_directory?(_1) }
          scopes = snapshot_dirs.map { |dir| [dir.basename.to_s, dir, snapshot_dirs] }
          scopes << ["current", site_dir, snapshot_dirs]

          scopes.flat_map do |version_name, source_root, excluded_roots|
            documents_for_scope(
              sample_set_key:,
              project_name:,
              project_code:,
              site_dir:,
              version_name:,
              source_root:,
              excluded_roots: source_root == site_dir ? excluded_roots : []
            )
          end
        end
      end
    end

    private

    attr_reader :context

    def documents_for_scope(sample_set_key:, project_name:, project_code:, site_dir:, version_name:, source_root:, excluded_roots:)
      scanner = ZipImportDocumentScanner.new(root: source_root)
      scan_result = scanner.call
      version_label = version_label_for_name(version_name)
      site_build_path = File.join(
        "external_samples",
        slug_for_name(project_name),
        site_build_segment_for_name(version_name)
      )

      scan_result.documents.filter_map do |candidate|
        source_file = Pathname(candidate.absolute_path)
        next if excluded_roots.any? { source_file.to_s.start_with?(_1.to_s + File::SEPARATOR) }

        renderable = scanner.renderable_document_file?(source_file)
        slug = document_slug_for_markdown(site_dir, candidate.logical_path)

        {
          project_code:,
          project_name:,
          project_description: "external_samples/#{sample_set_key} 配下のサンプル文書サイト",
          title: candidate.title,
          slug:,
          version_label:,
          source_commit_hash: "external-#{Digest::SHA1.hexdigest("#{project_name}/#{candidate.logical_path}/#{version_label}")[0, 12]}",
          source_dir: source_root,
          markdown_source_file: source_file,
          markdown_logical_relative_path: candidate.logical_path,
          markdown_entry_path: renderable ? site_page_path_for_markdown(candidate.logical_path, site_build_path) : nil,
          site_build_path: renderable ? site_build_path : nil,
          version_priority: source_root == site_dir ? 1 : 0,
          attachment_files: candidate.attachment_paths.map { Pathname(_1) }.sort_by { |path| [path == source_file ? 0 : 1, path.to_s] }
        }
      end
    end

    def method_missing(name, ...)
      if context.respond_to?(name, true)
        context.__send__(name, ...)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      context.respond_to?(name, true) || super
    end
  end

  module ExternalSampleSeedMethods
    def external_sample_documents(root)
      SeedSupport::ExternalSampleImporter.new(self).documents(root)
    end
  end
end
