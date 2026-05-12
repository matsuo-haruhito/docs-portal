namespace :recurring_jobs do
  desc "Sync and dispatch due recurring jobs"
  task dispatch: :environment do
    RecurringJobDispatcherJob.perform_now
  end
end
