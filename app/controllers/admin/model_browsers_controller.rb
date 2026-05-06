class Admin::ModelBrowsersController < Admin::BaseController
  before_action :require_admin_only!

  helper_method :entry_index_path, :record_summary_value

  def index
    @entries = Admin::ModelBrowserCatalog.entries
    @entry_summaries = @entries.index_with { build_summary(_1) }
  end

  def show
    @entry = Admin::ModelBrowserCatalog.fetch!(params[:model_key])
    @records = recent_scope(@entry).limit(20)
    @summary = build_summary(@entry)
  end

  private

  def build_summary(entry)
    scope = entry.model_class.all

    {
      total_count: scope.count,
      latest_updated_at: latest_updated_at_for(scope)
    }
  end

  def recent_scope(entry)
    scope = entry.model_class.all
    return scope.order(updated_at: :desc, id: :desc) if entry.model_class.column_names.include?("updated_at")

    scope.order(id: :desc)
  end

  def latest_updated_at_for(scope)
    return unless scope.model.column_names.include?("updated_at")

    scope.maximum(:updated_at)
  end

  def entry_index_path(entry)
    return if entry.index_path_helper.blank?

    view_context.public_send(entry.index_path_helper)
  end

  def record_summary_value(record, field)
    return "-" unless record.respond_to?(field)

    value = record.public_send(field)
    case value
    when Time, ActiveSupport::TimeWithZone
      I18n.l(value, format: :short)
    when TrueClass
      "yes"
    when FalseClass
      "no"
    when Array
      value.join(", ")
    else
      value.presence || "-"
    end
  end
end
