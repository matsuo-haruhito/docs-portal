require "fileutils"

module SeedSupport
  class MasterDataImporter
    private

    def seed_external_sample_files(sample_documents, now:)
      versions = versions_by_project_slug_and_label
      existing_files = DocumentFile.all.index_by(&:storage_key)
      file_rows = sample_documents.flat_map do |document_spec|
        version = versions.fetch(composite_key(document_spec[:project_code], document_spec[:slug], document_spec[:version_label]))
        document_spec[:attachment_files].each_with_index.map do |source_file, index|
          storage_key = external_storage_key_for_document_spec(source_file, document_spec)
          materialize_external_sample_file!(source_file, storage_key)
          file = existing_files[storage_key]
          {
            public_id: public_id_for(file, "file", storage_key),
            document_version_id: version.id,
            file_name: relative_path(source_file, document_spec[:source_dir]),
            content_type: content_type_for(source_file),
            storage_key:,
            file_size: File.size(source_file),
            sort_order: index
          }.merge(timestamps(file, now:))
        end
      end

      upsert_rows!(DocumentFile, file_rows.uniq { _1[:storage_key] }, unique_by: :index_document_files_on_storage_key)
    end

    def external_storage_key_for_document_spec(source_file, document_spec)
      File.join(
        "external_sample_seed_files",
        safe_storage_segment(document_spec[:project_code]),
        safe_storage_segment(document_spec[:slug]),
        safe_storage_segment(document_spec[:version_label]),
        relative_path(source_file, document_spec[:source_dir])
      )
    end

    def materialize_external_sample_file!(source_file, storage_key)
      root = DocumentFile.storage_root
      destination = root.join(storage_key).cleanpath
      root_path = root.expand_path.to_s
      destination_path = destination.expand_path.to_s

      unless destination_path == root_path || destination_path.start_with?(root_path + File::SEPARATOR)
        raise ApplicationError::BadRequest, "external sample storage key must stay under document_files"
      end

      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(source_file, destination)
    end

    def safe_storage_segment(value)
      raw = value.to_s.presence || "value"
      raw.parameterize.presence || Digest::SHA1.hexdigest(raw)[0, 12]
    end
  end
end
