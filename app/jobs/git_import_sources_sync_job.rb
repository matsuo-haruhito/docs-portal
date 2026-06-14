class GitImportSourcesSyncJob < ApplicationJob
  queue_as :default

  def perform(limit: nil)
    scope = GitImportSource.enabled_only.order(:id)
    scope = scope.limit(limit.to_i) if limit.present?

    scope.find_each do |source|
      GitImportSourceSyncer.new(source: source, actor: nil).call
    rescue => e
      Rails.logger.error(
        "Git import source sync failed: source_id=#{source.id} public_id=#{source.public_id} error=#{e.class}: #{e.message}"
      )
    end
  end
end
