require "digest"
require "fileutils"
require "pathname"
require "securerandom"

module GeneratedFiles
  module OutputWriters
    class DocumentVersion
      def initialize(
        project_code:,
        document_slug:,
        document_title:,
        project_name: nil,
        project_description: nil,
        create_project_if_missing: false,
        document_category: "other",
        document_kind: "mixed",
        visibility_policy: "internal_only",
        importance_level: "reference",
        version_label_prefix: "generated",
        source_identifier: nil,
        idempotency_key: nil,
        dispatch_claim: nil,
        snapshot_kind: "attachment",
        root: nil
      )
        @project_code = project_code
        @project_name = project_name
        @project_description = project_description
        @create_project_if_missing = create_project_if_missing
        @document_slug = document_slug
        @document_title = document_title
        @document_category = document_category
        @document_kind = document_kind
        @visibility_policy = visibility_policy
        @importance_level = importance_level
        @version_label_prefix = version_label_prefix
        @source_identifier = source_identifier
        @idempotency_key = idempotency_key
        @dispatch_claim = dispatch_claim
        @snapshot_kind = snapshot_kind
        @root = Pathname(root || default_root).expand_path
      end

      def write(artifacts)
        artifacts = Array(artifacts)
        raise ArgumentError, "artifacts are required" if artifacts.empty?

        created_storage_paths = []
        ActiveRecord::Base.transaction do
          with_dispatch_ownership do
            document = find_or_create_document!
            document.lock!
            version = idempotent_version(document)

            unless version
              version = create_version!(document, artifacts)
              artifacts.each_with_index do |artifact, index|
                create_document_file!(version, artifact, index, created_storage_paths:)
              end
            end

            ["document_versions/#{version.public_id}"]
          end
        end
      rescue StandardError
        Array(created_storage_paths).each { FileUtils.rm_f(_1) }
        raise
      end

      private

      attr_reader :project_code, :project_name, :project_description, :create_project_if_missing,
        :document_slug, :document_title, :document_category, :document_kind,
        :visibility_policy, :importance_level, :version_label_prefix, :source_identifier,
        :idempotency_key, :dispatch_claim, :snapshot_kind, :root

      def with_dispatch_ownership(&block)
        return yield unless dispatch_claim

        GeneratedFiles::EventDispatchLease.with_ownership!(dispatch_claim, &block)
      end

      def default_root
        if defined?(Rails)
          Rails.root
        else
          Pathname(__dir__).join("..", "..", "..", "..").expand_path
        end
      end

      def project
        @project ||= begin
          existing = Project.find_by(code: project_code)
          return existing if existing
          raise ActiveRecord::RecordNotFound, "Generated output project not found: #{project_code}" unless create_project_if_missing

          Project.create!(
            code: project_code,
            name: project_name.presence || project_code,
            description: project_description,
            active: true
          )
        end
      end

      def find_or_create_document!
        project.documents.find_or_create_by!(slug: document_slug) do |document|
          document.title = document_title
          document.category = document_category
          document.document_kind = document_kind
          document.visibility_policy = visibility_policy
          document.importance_level = importance_level
        end.tap do |document|
          document.update!(title: document_title) if document.title != document_title
        end
      end

      def idempotent_version(document)
        return if idempotency_key.blank?

        document.document_versions.find_by(source_commit_hash: source_commit_hash)
      end

      def create_version!(document, artifacts)
        version = document.document_versions.create!(
          version_label: unique_version_label(document),
          source_commit_hash: source_commit_hash,
          status: :published,
          published_at: Time.current,
          snapshot_kind: snapshot_kind
        )
        primary_artifact = artifacts.first
        version.assign_source_path_metadata!(source_path: primary_artifact.path, snapshot_kind: snapshot_kind)
        version.assign_search_body_text_from_markdown!(
          markdown: artifacts.map(&:content).join("\n\n"),
          source_path: primary_artifact.path
        )
        version.save!
        version
      end

      def source_commit_hash
        @source_commit_hash ||= begin
          base = source_identifier.presence
          base ||= idempotency_key.present? ? "generated:#{document_slug}" : "generated:#{document_slug}:#{Time.current.to_i}"
          idempotency_key.present? ? "#{base}:event:#{idempotency_key}" : base
        end
      end

      def create_document_file!(version, artifact, index, created_storage_paths:)
        storage_key = storage_key_for(version, artifact)
        absolute_path = ::DocumentFile.storage_root.join(storage_key)
        created_storage_paths << absolute_path
        FileUtils.mkdir_p(absolute_path.dirname)
        absolute_path.write(artifact.content, mode: "w", encoding: "UTF-8")

        file = version.document_files.create!(
          file_name: artifact.path,
          content_type: artifact.content_type,
          file_size: artifact.content.bytesize,
          storage_key: storage_key,
          scan_status: :scan_pending,
          sort_order: index
        )
        file.assign_search_text_from_path!(artifact.path)
        file.save!
      end

      def storage_key_for(version, artifact)
        safe_path = artifact.path.to_s.tr("\\/", "_").presence || "generated-file"
        "generated_files/#{version.id}/#{SecureRandom.uuid}-#{safe_path}"
      end

      def unique_version_label(document)
        base = "#{version_label_prefix}-#{Time.current.strftime("%Y%m%d%H%M%S")}"
        candidate = base
        index = 2
        while document.document_versions.exists?(version_label: candidate)
          candidate = "#{base}-#{index}"
          index += 1
        end
        candidate
      end
    end
  end
end
