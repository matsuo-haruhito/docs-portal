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
        document_category: "other",
        document_kind: "mixed",
        visibility_policy: "internal_only",
        importance_level: "reference",
        version_label_prefix: "generated",
        source_identifier: nil,
        snapshot_kind: "attachment",
        root: nil
      )
        @project_code = project_code
        @document_slug = document_slug
        @document_title = document_title
        @document_category = document_category
        @document_kind = document_kind
        @visibility_policy = visibility_policy
        @importance_level = importance_level
        @version_label_prefix = version_label_prefix
        @source_identifier = source_identifier
        @snapshot_kind = snapshot_kind
        @root = Pathname(root || default_root).expand_path
      end

      def write(artifacts)
        artifacts = Array(artifacts)
        raise ArgumentError, "artifacts are required" if artifacts.empty?

        ActiveRecord::Base.transaction do
          document = find_or_create_document!
          version = create_version!(document, artifacts)
          artifacts.each_with_index do |artifact, index|
            create_document_file!(version, artifact, index)
          end
          ["document_versions/#{version.public_id}"]
        end
      end

      private

      attr_reader :project_code, :document_slug, :document_title, :document_category, :document_kind,
        :visibility_policy, :importance_level, :version_label_prefix, :source_identifier, :snapshot_kind, :root

      def default_root
        if defined?(Rails)
          Rails.root
        else
          Pathname(__dir__).join("..", "..", "..", "..").expand_path
        end
      end

      def project
        @project ||= Project.find_by!(code: project_code)
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

      def create_version!(document, artifacts)
        version = document.document_versions.create!(
          version_label: unique_version_label(document),
          source_commit_hash: source_identifier.presence || "generated:#{document_slug}:#{Time.current.to_i}",
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

      def create_document_file!(version, artifact, index)
        storage_key = storage_key_for(version, artifact)
        absolute_path = ::DocumentFile.storage_root.join(storage_key)
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
