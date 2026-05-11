class ExternalFolderSyncJob < ApplicationJob
  queue_as :default

  def perform(external_folder_sync_source_id, actor_id = nil)
    source = ExternalFolderSyncSource.find(external_folder_sync_source_id)
    actor = actor_id.present? ? User.find(actor_id) : source.created_by

    ExternalFolderSync::Runner.new(source:, mode: :apply, actor:).call
  end
end
