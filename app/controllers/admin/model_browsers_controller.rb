class Admin::ModelBrowsersController < Admin::BaseController
  before_action :require_admin_only!

  helper_method :entry_index_path, :record_summary_value, :summary_field_label

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

  def summary_field_label(entry, field)
    association_summary_field_label(entry, field) || generic_summary_field_label(field)
  end

  def record_summary_value(record, field)
    return "-" unless record.respond_to?(field)

    value = record.public_send(field)
    case value
    when Time, ActiveSupport::TimeWithZone
      I18n.l(value, format: :short)
    when TrueClass
      I18n.t("labels.boolean.true")
    when FalseClass
      I18n.t("labels.boolean.false")
    when Array
      value.join(", ")
    else
      value.presence || "-"
    end
  end

  def association_summary_field_label(entry, field)
    field_name = field.to_s
    return unless field_name.end_with?("_id")

    association_name = field_name.delete_suffix("_id")
    explicit_label = I18n.t("labels.model_browser_associations.#{association_name}", default: nil)
    return explicit_label if explicit_label.is_a?(String)

    reflection = entry.model_class.reflect_on_association(association_name.to_sym)
    return unless reflection

    human_name = reflection.klass.model_name.human
    return if human_name == reflection.klass.model_name.name.humanize

    human_name
  end

  def generic_summary_field_label(field)
    explicit_label = I18n.t("labels.model_browser_fields.#{field}", default: nil)
    return explicit_label if explicit_label.is_a?(String)

    field.to_s.humanize
  end
end
