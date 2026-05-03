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
            renderable_files_for_scope(source_root, excluded_roots: source_root == site_dir ? excluded_roots : []).map do |source_file|
              logical_relative_path = relative_path(source_file, source_root)
              slug = document_slug_for_markdown(site_dir, logical_relative_path)
              version_label = version_label_for_name(version_name)
              site_build_path = File.join(
                "external_samples",
                slug_for_name(project_name),
                site_build_segment_for_name(version_name)
              )

              {
                project_code:,
                project_name:,
                project_description: "external_samples/#{sample_set_key} 配下のサンプル文書サイト",
                title: document_title_for_markdown(logical_relative_path, site_dir),
                slug:,
                version_label:,
                source_commit_hash: "external-#{Digest::SHA1.hexdigest("#{project_name}/#{logical_relative_path}/#{version_label}")[0, 12]}",
                source_dir: source_root,
                markdown_source_file: Pathname(source_file),
                markdown_logical_relative_path: logical_relative_path,
                markdown_entry_path: site_page_path_for_markdown(logical_relative_path, site_build_path),
                site_build_path:,
                version_priority: source_root == site_dir ? 1 : 0,
                attachment_files: attachment_files_for(source_file, logical_relative_path, source_root)
              }
            end
          end
        end
      end
    end

    private

    attr_reader :context

    def renderable_files_for_scope(source_root, excluded_roots: [])
      Dir.glob(source_root.join("**/*").to_s).select do |path|
        next false unless File.file?(path)
        next false unless DocusaurusBuilder.renderable_document_file?(path)

        excluded_roots.none? { Pathname(path).to_s.start_with?(_1.to_s + File::SEPARATOR) }
      end.sort
    end

    def attachment_files_for(source_file, logical_relative_path, source_root)
      files = related_attachment_files(source_file, logical_relative_path, source_root).map { Pathname(_1) }
      files.unshift(Pathname(source_file)) if DocusaurusBuilder.diagram_file?(source_file)
      files
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
