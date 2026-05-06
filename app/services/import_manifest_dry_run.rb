class ImportManifestDryRun
  def initialize(manifest:)
    @manifest = manifest
  end

  def call
    grouped_hashes = grouped_documents.map do |project, payloads|
      result = ImportDryRunValidator.new(project:, entries: build_entries(payloads)).call
      project_hash(project, payloads, ImportDryRunHashPresenter.new(result).call)
    end

    {
      valid: grouped_hashes.all? { _1[:valid] },
      source_commit_hash: manifest["source_commit_hash"],
      summary: combined_summary(grouped_hashes),
      projects: grouped_hashes,
      items: grouped_hashes.flat_map { _1[:items] },
      warnings: grouped_hashes.flat_map { _1[:warnings] },
      errors: grouped_hashes.flat_map { _1[:errors] }
    }
  end

  private

  attr_reader :manifest

  def grouped_documents
    manifest.fetch("documents", []).group_by do |payload|
      Project.find_by!(code: payload.fetch("project_code"))
    end
  end

  def build_entries(payloads)
    payloads.map do |payload|
      {
        source_path: source_path_for(payload),
        title: payload["title"],
        frontmatter: payload.slice("category", "document_kind", "visibility_policy", "snapshot_kind"),
        content: nil
      }
    end
  end

  def source_path_for(payload)
    payload["source_relative_path"].presence ||
      payload["source_path"].presence ||
      payload["markdown_entry_path"].presence ||
      payload["pdf_snapshot_path"].presence ||
      payload["site_build_path"].presence
  end

  def project_hash(project, payloads, hash)
    payload_by_source_path = payloads.index_by { source_path_for(_1) }
    items = hash[:items].map do |item|
      payload = payload_by_source_path[item[:source_path]]
      item.merge(
        project_code: project.code,
        version_label: payload&.fetch("version_label", nil),
        files_count: Array(payload&.dig("files")).size
      )
    end

    {
      project_code: project.code,
      project_public_id: project.public_id,
      valid: hash[:valid],
      summary: hash[:summary],
      items:,
      warnings: items.flat_map { _1[:warnings] },
      errors: items.flat_map { _1[:errors] }
    }
  end

  def combined_summary(grouped_hashes)
    {
      total: grouped_hashes.sum { _1.dig(:summary, :total).to_i },
      create_count: grouped_hashes.sum { _1.dig(:summary, :create_count).to_i },
      update_count: grouped_hashes.sum { _1.dig(:summary, :update_count).to_i },
      valid_count: grouped_hashes.sum { _1.dig(:summary, :valid_count).to_i },
      invalid_count: grouped_hashes.sum { _1.dig(:summary, :invalid_count).to_i },
      warning_count: grouped_hashes.sum { _1.dig(:summary, :warning_count).to_i },
      error_count: grouped_hashes.sum { _1.dig(:summary, :error_count).to_i },
      source_paths: grouped_hashes.flat_map { _1.dig(:summary, :source_paths) || [] }
    }
  end
end
