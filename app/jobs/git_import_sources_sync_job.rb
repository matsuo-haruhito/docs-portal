class GitImportSourcesSyncJob < ApplicationJob
  queue_as :default

  def perform(limit: nil)
    scope = GitImportSource.enabled_only.order(:id)
    scope = scope.limit(limit.to_i) if limit.present?

    errors = scope.to_a.filter_map do |source|
      GitImportSourceSyncer.new(source:, actor: nil).call
      nil
    rescue StandardError => e
      Rails.logger.error(
        "Git import source sync failed: source_id=#{source.id} public_id=#{source.public_id} error=#{e.class}: #{e.message}"
      )
      e
    end
    raise errors.first if errors.any?
  end
end
