class PermissionChangePreviewHash
  def initialize(project:, viewers:, grant_document_ids: [], revoke_document_ids: [], grant_download_document_ids: [], revoke_download_document_ids: [], grant_project_membership: false, revoke_project_membership: false, scope: nil)
    @project = project
    @viewers = Array(viewers)
    @grant_document_ids = Array(grant_document_ids).map(&:to_i)
    @revoke_document_ids = Array(revoke_document_ids).map(&:to_i)
    @grant_download_document_ids = Array(grant_download_document_ids).map(&:to_i)
    @revoke_download_document_ids = Array(revoke_download_document_ids).map(&:to_i)
    @grant_project_membership = grant_project_membership
    @revoke_project_membership = revoke_project_membership
    @scope = scope
  end

  def call
    {
      project: project_hash,
      summary: summary_hash,
      companies: company_hashes,
      viewers: viewer_hashes
    }
  end

  private

  attr_reader :project, :viewers, :grant_document_ids, :revoke_document_ids, :grant_download_document_ids, :revoke_download_document_ids, :grant_project_membership, :revoke_project_membership, :scope

  def project_hash
    {
      public_id: project.public_id,
      code: project.code,
      name: project.name
    }
  end

  def summary_hash
    {
      total_viewers: viewer_hashes.size,
      changed_viewers: viewer_hashes.count { _1[:changed] },
      gained_documents: viewer_hashes.flat_map { _1[:gained_documents] }.uniq { _1[:public_id] }.size,
      lost_documents: viewer_hashes.flat_map { _1[:lost_documents] }.uniq { _1[:public_id] }.size,
      gained_download_documents: viewer_hashes.flat_map { _1[:gained_download_documents] }.uniq { _1[:public_id] }.size,
      lost_download_documents: viewer_hashes.flat_map { _1[:lost_download_documents] }.uniq { _1[:public_id] }.size
    }
  end

  def company_hashes
    grouped = viewers.group_by(&:company)

    grouped.filter_map do |company, company_viewers|
      next if company.blank?

      hashes = viewer_hashes.select { company_viewers.map(&:id).include?(_1[:id]) }

      {
        public_id: company.public_id,
        domain: company.domain,
        name: company.display_name,
        total_viewers: hashes.size,
        changed_viewers: hashes.count { _1[:changed] },
        gained_documents: hashes.flat_map { _1[:gained_documents] }.uniq { _1[:public_id] }.size,
        lost_documents: hashes.flat_map { _1[:lost_documents] }.uniq { _1[:public_id] }.size,
        gained_download_documents: hashes.flat_map { _1[:gained_download_documents] }.uniq { _1[:public_id] }.size,
        lost_download_documents: hashes.flat_map { _1[:lost_download_documents] }.uniq { _1[:public_id] }.size
      }
    end.sort_by { [_1[:domain].to_s, _1[:public_id].to_s] }
  end

  def viewer_hashes
    @viewer_hashes ||= dry_run.changes.map { viewer_hash(_1) }
  end

  def viewer_hash(change)
    gained = change.gained_documents
    lost = change.lost_documents
    gained_download = change.gained_downloadable_documents
    lost_download = change.lost_downloadable_documents

    {
      id: change.viewer.id,
      public_id: change.viewer.public_id,
      email_address: change.viewer.email_address,
      user_type: change.viewer.user_type,
      company_id: change.viewer.company&.public_id,
      changed: change.changed?,
      before_visible_count: change.before_documents.size,
      after_visible_count: change.after_documents.size,
      before_downloadable_count: change.before_downloadable_documents.size,
      after_downloadable_count: change.after_downloadable_documents.size,
      gained_documents: gained.map { document_hash(_1) },
      lost_documents: lost.map { document_hash(_1) },
      unchanged_documents: change.unchanged_documents.map { document_hash(_1) },
      gained_download_documents: gained_download.map { document_hash(_1) },
      lost_download_documents: lost_download.map { document_hash(_1) },
      unchanged_download_documents: change.unchanged_downloadable_documents.map { document_hash(_1) }
    }
  end

  def dry_run
    @dry_run ||= PermissionChangeDryRun.new(
      project:,
      viewers:,
      grant: {
        document_ids: grant_document_ids,
        download_document_ids: grant_download_document_ids,
        project_membership: grant_project_membership
      },
      revoke: {
        document_ids: revoke_document_ids,
        download_document_ids: revoke_download_document_ids,
        project_membership: revoke_project_membership
      },
      scope:
    ).call
  end

  def document_hash(document)
    {
      public_id: document.public_id,
      title: document.title,
      slug: document.slug,
      visibility_policy: document.visibility_policy
    }
  end
end
