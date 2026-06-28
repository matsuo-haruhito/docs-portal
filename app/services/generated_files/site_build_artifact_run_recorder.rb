module GeneratedFiles
  class SiteBuildArtifactRunRecorder
    EVENT_SOURCE = "docusaurus_site_build"
    JOB_ID = "docusaurus_site_build_artifact"
    GENERATOR = "docusaurus_site_build"
    OUTPUT_WRITER = "docs_site_artifact"
    DEFAULT_ARTIFACT_NAME = "docs-site"
    DEFAULT_MANIFEST_PATH = "publish/manifest/publish.json"

    STATUS_MAP = {
      "success" => "completed",
      "completed" => "completed",
      "failure" => "failed",
      "failed" => "failed",
      "cancelled" => "skipped",
      "skipped" => "skipped",
      "in_progress" => "running",
      "running" => "running"
    }.freeze

    ARTIFACT_KEYS = {
      "name" => %w[name artifact_name],
      "source_repo" => %w[source_repo repository repository_full_name],
      "source_branch" => %w[source_branch branch ref_name],
      "source_commit_hash" => %w[source_commit_hash commit_sha sha head_sha],
      "workflow_run_id" => %w[workflow_run_id run_id],
      "workflow_run_attempt" => %w[workflow_run_attempt run_attempt attempt],
      "manifest_path" => %w[manifest_path]
    }.freeze

    SAFE_PATH_PATTERN = /\A(?!\/)(?![A-Za-z]:[\\\/])(?!.*(?:\A|\/)\.\.(?:\/|\z))[A-Za-z0-9._\-\/]+\z/

    def self.call(...)
      new.call(...)
    end

    def call(status:, artifact: {}, workflow: {}, manifest: {}, started_at: nil, finished_at: nil)
      artifact = normalized_hash(artifact)
      workflow = normalized_hash(workflow)
      manifest = normalized_hash(manifest)
      safe_artifact = build_artifact_metadata(artifact:, workflow:)
      manifest_count = manifest_document_count(manifest)
      status_value = normalized_status(status)

      GeneratedFileRun.create!(
        job_id: JOB_ID,
        generator: GENERATOR,
        output_writer: OUTPUT_WRITER,
        status: status_value,
        event_source: EVENT_SOURCE,
        source_paths: [safe_artifact.fetch("manifest_path", DEFAULT_MANIFEST_PATH)],
        changed_files: [],
        generated_paths: generated_paths_for(safe_artifact),
        metadata: metadata_for(safe_artifact:, manifest_count:),
        started_at: parsed_time(started_at),
        finished_at: parsed_time(finished_at)
      )
    end

    private

    def normalized_status(value)
      STATUS_MAP.fetch(value.to_s) { raise ArgumentError, "unsupported site build status: #{value.inspect}" }
    end

    def build_artifact_metadata(artifact:, workflow:)
      ARTIFACT_KEYS.each_with_object({}) do |(target_key, source_keys), result|
        value = first_present_value(source_keys, artifact, workflow)
        value = DEFAULT_ARTIFACT_NAME if target_key == "name" && value.blank?
        value = DEFAULT_MANIFEST_PATH if target_key == "manifest_path" && value.blank?
        value = safe_metadata_value(target_key, value)
        result[target_key] = value if value.present?
      end
    end

    def metadata_for(safe_artifact:, manifest_count:)
      metadata = {
        "artifact" => safe_artifact,
        "read_only_evidence" => true,
        "raw_payload_saved" => false
      }
      metadata["manifest_document_count"] = manifest_count if manifest_count
      metadata
    end

    def generated_paths_for(safe_artifact)
      artifact_name = safe_artifact.fetch("name", DEFAULT_ARTIFACT_NAME)
      manifest_path = safe_artifact.fetch("manifest_path", DEFAULT_MANIFEST_PATH)

      ["#{artifact_name}.tar.gz", manifest_path].uniq
    end

    def manifest_document_count(manifest)
      explicit_count = manifest["manifest_document_count"] || manifest["document_count"]
      return explicit_count.to_i if explicit_count.to_s.match?(/\A\d+\z/)

      documents = manifest["documents"] || manifest["document_files"] || manifest["files"]
      documents.size if documents.respond_to?(:size)
    end

    def first_present_value(keys, *sources)
      keys.each do |key|
        sources.each do |source|
          value = source[key]
          return value if value.present?
        end
      end
      nil
    end

    def safe_metadata_value(key, value)
      return if value.blank?

      text = value.to_s.squish
      return safe_path(text) if key == "manifest_path"
      return safe_commit(text) if key == "source_commit_hash"
      return text if key.in?(%w[workflow_run_id workflow_run_attempt]) && text.match?(/\A\d+\z/)
      return text if key.in?(%w[name source_repo source_branch]) && safe_scalar?(text)
    end

    def safe_commit(value)
      value if value.match?(/\A[0-9a-f]{7,40}\z/i)
    end

    def safe_path(value)
      value if value.match?(SAFE_PATH_PATTERN)
    end

    def safe_scalar?(value)
      !value.match?(/[\r\n\u0000]/) && value.length <= 200
    end

    def parsed_time(value)
      return if value.blank?
      return value if value.respond_to?(:in_time_zone)

      Time.zone.parse(value.to_s)
    end

    def normalized_hash(value)
      return {} unless value.respond_to?(:to_h)

      value.to_h.deep_stringify_keys
    end
  end
end
