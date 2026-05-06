class GitImportSourceSyncer
  def initialize(source:, actor:)
    @source = source
    @actor = actor
  end

  def call
    ensure_enabled!

    run = build_run
    run.update!(status: :running, started_at: Time.current)

    GitRepositorySnapshotFetcher.new(source: @source).call do |snapshot|
      run.update!(commit_sha: snapshot.commit_sha)

      if snapshot.commit_sha == @source.last_synced_commit_sha
        run.finish!(status: :skipped, summary: { reason: "already_synced", commit_sha: snapshot.commit_sha })
        return run
      end

      manifest_result = GitImportManifestBuilder.new(
        source: @source,
        worktree_path: snapshot.worktree_path,
        commit_sha: snapshot.commit_sha
      ).call

      if manifest_result.manifest.fetch(:documents).blank?
        run.finish!(status: :skipped, summary: manifest_result.summary.merge(reason: "no_documents"))
        @source.mark_synced!(snapshot.commit_sha)
        return run
      end

      publish_job = DocumentImporter.new(
        artifact_root: manifest_result.artifact_root.to_s,
        manifest_path: manifest_result.manifest_path.to_s,
        actor: @actor
      ).call

      summary = manifest_result.summary.merge(publish_job_id: publish_job.public_id)
      run.finish!(status: :imported, summary: summary)
      @source.mark_synced!(snapshot.commit_sha)
    end

    run
  rescue => e
    run&.finish!(status: :failed, summary: run.summary_json.presence || {}, error_message: e.message)
    raise
  end

  private

  def ensure_enabled!
    raise ApplicationError::BadRequest, "Git import source is disabled" unless @source.enabled?
  end

  def build_run
    @source.git_import_runs.create!(
      import_mode: :pull,
      provider: @source.provider,
      repository_full_name: @source.repository_full_name,
      branch: @source.branch,
      source_path: @source.normalized_source_path,
      status: :pending,
      summary_json: {}
    )
  end
end
