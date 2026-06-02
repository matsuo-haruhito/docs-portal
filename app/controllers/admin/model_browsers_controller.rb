class Admin::ModelBrowsersController < Admin::BaseController
  before_action :require_admin_only!

  MODEL_BROWSER_QUERY_MAX_LENGTH = 100
  TEXT_SEARCH_COLUMN_TYPES = %i[string text].freeze

  helper_method :entry_index_path, :record_summary_value, :summary_field_label

  def index
    @entries = Admin::ModelBrowserCatalog.entries
    @entry_groups = Admin::ModelBrowserCatalog.grouped_entries(@entries)
    @entry_summaries = @entries.index_with { build_summary(_1) }
  end

  def show
    @entry = Admin::ModelBrowserCatalog.fetch!(params[:model_key])
    @query = normalized_model_browser_query
    @searchable_field_labels = searchable_fields(@entry).index_with { summary_field_label(@entry, _1) }
    @records = model_browser_records(@entry, @query)
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

  def model_browser_records(entry, query)
    scope = recent_scope(entry)
    return scope.limit(20) if query.blank?

    predicates = search_predicates(entry, query)
    return scope.none if predicates.blank?

    scope.where(predicates.reduce { |combined, predicate| combined.or(predicate) }).limit(20)
  end

  def search_predicates(entry, query)
    table = entry.model_class.arel_table
    predicates = []

    if query.match?(/\A\d+\z/) && entry.model_class.column_names.include?("id")
      predicates << table[:id].eq(query.to_i)
    end

    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    searchable_fields(entry).each do |field|
      predicates << table[field].matches(like_query)
    end

    predicates
  end

  def searchable_fields(entry)
    entry.summary_fields.select do |field|
      searchable_text_column?(entry.model_class, field)
    end
  end

  def searchable_text_column?(model_class, field)
    column = model_class.columns_hash[field.to_s]
    return false unless column
    return false if association_id_field?(field)

    TEXT_SEARCH_COLUMN_TYPES.include?(column.type)
  end

  def association_id_field?(field)
    field_name = field.to_s
    field_name.end_with?("_id") && field_name != "public_id"
  end

  def normalized_model_browser_query
    params[:q].to_s.strip.presence&.slice(0, MODEL_BROWSER_QUERY_MAX_LENGTH)
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
