class Admin::ModelBrowsersController < Admin::BaseController
  before_action :require_admin_only!

  MODEL_BROWSER_QUERY_MAX_LENGTH = 100
  ASSOCIATION_SUMMARY_LABEL_METHODS = %i[display_name name title code public_id email_address].freeze

  helper_method :entry_index_path, :model_browser_index_return_path, :record_summary_value, :summary_field_label

  def index
    @query = normalized_model_browser_query(max_length: MODEL_BROWSER_QUERY_MAX_LENGTH)
    @entries = filter_entries(Admin::ModelBrowserCatalog.entries, @query)
    @entry_groups = Admin::ModelBrowserCatalog.grouped_entries(@entries)
    @entry_summaries = @entries.index_with { build_summary(_1) }
  end

  def show
    @entry = Admin::ModelBrowserCatalog.fetch!(params[:model_key])
    @query = normalized_model_browser_query(max_length: MODEL_BROWSER_QUERY_MAX_LENGTH)
    @model_browser_index_query = normalized_model_browser_index_return_query
    @existing_screen_query_handoff_param = model_browser_query_handoff_param(@entry, @query)
    @searchable_field_labels = searchable_fields(@entry).index_with { summary_field_label(@entry, _1) }
    @records = model_browser_records(@entry, @query)
    @summary = build_summary(@entry)
  end

  private

  def normalized_model_browser_query(max_length: nil)
    query = params[:q].to_s.strip
    return query if max_length.blank?

    query.presence&.slice(0, max_length)
  end

  def normalized_model_browser_index_return_query
    query = params[:model_browser_q].to_s.strip.presence&.slice(0, MODEL_BROWSER_QUERY_MAX_LENGTH)
    return if query.blank?
    return if query.match?(/\A(?:https?:\/\/|\/\/|\/)/i)

    query
  end

  def model_browser_index_return_path
    return admin_model_browser_path if @model_browser_index_query.blank?

    admin_model_browser_path(q: @model_browser_index_query)
  end

  def filter_entries(entries, query)
    return entries if query.blank?

    normalized_query = query.downcase
    entries.select { model_browser_entry_search_text(_1).include?(normalized_query) }
  end

  def model_browser_entry_search_text(entry)
    [
      entry.label,
      entry.key,
      entry.description,
      Admin::ModelBrowserCatalog.group_label(entry.group)
    ].join(" ").downcase
  end

  def build_summary(entry)
    Admin::ModelBrowserSummary.for(entry)
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
    Admin::ModelBrowserCatalog.searchable_summary_fields(entry)
  end

  def recent_scope(entry)
    scope = entry.model_class.all
    return scope.order(updated_at: :desc, id: :desc) if entry.model_class.column_names.include?("updated_at")

    scope.order(id: :desc)
  end

  def entry_index_path(entry, query: nil)
    return if entry.index_path_helper.blank?

    handoff_param = model_browser_query_handoff_param(entry, query)
    if handoff_param
      view_context.public_send(entry.index_path_helper, handoff_param => query)
    else
      view_context.public_send(entry.index_path_helper)
    end
  end

  def model_browser_query_handoff_param(entry, query)
    return if query.blank?
    return if query.match?(/\A\d+\z/)

    Admin::ModelBrowserCatalog.query_handoff_param_for(entry)
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
      association_summary_value(record, field, value) || value.presence || "-"
    end
  end

  def association_summary_value(record, field, value)
    return if value.blank?

    reflection = association_summary_reflection(record.class, field)
    return unless reflection

    associated_record = record.public_send(reflection.name)
    label = association_summary_record_label(associated_record)
    return if label.blank?

    "#{label}（ID: #{value}）"
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def association_summary_record_label(associated_record)
    return unless associated_record

    ASSOCIATION_SUMMARY_LABEL_METHODS.each do |method_name|
      next unless associated_record.respond_to?(method_name)

      label = associated_record.public_send(method_name)
      return label.to_s if label.present?
    end

    nil
  end

  def association_summary_reflection(model_class, field)
    field_name = field.to_s
    return unless field_name.end_with?("_id")

    association_name = field_name.delete_suffix("_id")
    model_class.reflect_on_association(association_name.to_sym)
  end

  def association_summary_field_label(entry, field)
    reflection = association_summary_reflection(entry.model_class, field)
    return unless reflection

    association_name = reflection.name
    explicit_label = I18n.t("labels.model_browser_associations.#{association_name}", default: nil)
    return explicit_label if explicit_label.is_a?(String)

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