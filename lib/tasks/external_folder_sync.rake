namespace :external_folder_sync do
  desc "Run all enabled external folder sync sources"
  task sync_all: :environment do
    ExternalFolderSyncSource.enabled_only.find_each do |source|
      puts "Syncing #{source.provider}: #{source.name} (#{source.public_id})"
      ExternalFolderSync::Runner.new(source:, mode: :apply, actor: source.created_by).call
    rescue => e
      warn "Failed to sync #{source.public_id}: #{e.message}"
    end
  end

  desc "Enqueue all enabled external folder sync sources"
  task enqueue_all: :environment do
    ExternalFolderSyncSource.enabled_only.find_each do |source|
      ExternalFolderSyncJob.perform_later(source.id, source.created_by_id)
      puts "Enqueued #{source.provider}: #{source.name} (#{source.public_id})"
    end
  end

  desc "Run one external folder sync source by public_id: bin/rails external_folder_sync:sync[efs_xxx]"
  task :sync, [:public_id] => :environment do |_task, args|
    public_id = args[:public_id].to_s
    raise "public_id is required" if public_id.blank?

    source = ExternalFolderSyncSource.find_by!(public_id:)
    ExternalFolderSync::Runner.new(source:, mode: :apply, actor: source.created_by).call
    puts "Synced #{source.provider}: #{source.name} (#{source.public_id})"
  end
end
