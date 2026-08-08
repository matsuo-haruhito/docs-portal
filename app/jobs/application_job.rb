class ApplicationJob < ActiveJob::Base
  private

  def read_only_maintenance?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("READ_ONLY_MAINTENANCE", nil))
  end
end
