class Admin::ModelBrowserSummary
  def self.for(entry)
    new(entry).call
  end

  def initialize(entry)
    @entry = entry
  end

  def call
    scope = entry.model_class.all

    {
      total_count: scope.count,
      latest_updated_at: latest_updated_at_for(scope)
    }
  end

  private

  attr_reader :entry

  def latest_updated_at_for(scope)
    return unless scope.model.column_names.include?("updated_at")

    scope.maximum(:updated_at)
  end
end
