require "csv"

class Admin::DocumentUsageReportsController < Admin::BaseController
  before_action :require_admin_only!

  include Admin::BoundedProjectOptions

  DOCUMENT_USAGE_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  CSV_HEADERS = [
    "文書名",
    "slug",
    "カテゴリ",
    "種別",
    "公開範囲",
    "利用",
    "閲覧",
    "ダウンロード",
    "既読確認",
    "最終アクセス"
  ].freeze

  def index
    @selected_project = selected_report_project
    @projects = bounded_project_options(@selected_project)
    @usage_filter = usage_filter_param
    @sort_order = sort_order_param
    @query = query_param
    @ignored_date_filters = []
    @from_date = date_param(:from)
    @to_date = date_param(:to)
    @report_hash = build_report_hash(@selected_project) if @selected_project

    respond_to do |format|
      format.html
      format.csv do
        if @report_hash
          send_data document_usage_report_csv,
                    filename: document_usage_report_csv_filename,
                    type: "text/csv; charset=utf-8"
        else
          redirect_to admin_document_usage_reports_path, alert: "CSV出力には案件選択が必要です。"
        end
      end
      format.json do
        if @report_hash
          render json: document_usage_report_metadata
        else
          redirect_to admin_document_usage_reports_path, alert: "CSV出力には案件選択が必要です。"
        end
      end
    end
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def selected_report_project
    return if params[:project_id].blank?

    Project.find_by(id: params[:project_id])
  end

  def usage_filter_param
    normalized_enum_param(params[:usage_filter], allowed: %w[all used unused], default: "all")
  end

  def sort_order_param
    normalized_enum_param(params[:sort_order], allowed: %w[title last_accessed_desc last_accessed_asc], default: "title")
  end

  def query_param
    query = Array.wrap(params[:q]).compact_blank.first.to_s.squish.presence

    query&.slice(0, DOCUMENT_USAGE_QUERY_MAX_LENGTH)
  end

  def date_param(name)
    candidate = Array.wrap(params[name]).compact_blank.first
    return if candidate.blank?

    Date.iso8601(candidate)
  rescue ArgumentError
    @ignored_date_filters << name
    nil
  end

  def normalized_enum_param(value, allowed:, default:)
    candidate = Array.wrap(value).compact_blank.first

    allowed.include?(candidate) ? candidate : default
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern",
      pattern:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.document_usage_report_project_option_label(project) }
  end

  def build_report_hash(project)
    result = DocumentUsageReport.new(project:, from: report_from, to: report_to).call
    report_hash = DocumentUsageReportHash.new(result).call

    report_hash.merge(documents: sort_rows(filter_rows(report_hash[:documents])))
  end

  def report_from
    @from_date&.beginning_of_day
  end

  def report_to
    @to_date&.end_of_day
  end

  def filter_rows(rows)
    filtered_rows = case @usage_filter
                    when "used"
                      rows.select { _1[:used] }
                    when "unused"
                      rows.reject { _1[:used] }
                    else
                      rows
                    end

    filter_rows_by_query(filtered_rows)
  end

  def filter_rows_by_query(rows)
    return rows if @query.blank?

    rows.select { query_matches_row?(_1) }
  end

  def query_matches_row?(row)
    needle = @query.downcase

    [row[:title], row[:slug]].any? do |value|
      value.to_s.downcase.include?(needle)
    end
  end

  def sort_rows(rows)
    case @sort_order
    when "last_accessed_desc"
      sort_rows_by_last_accessed(rows).reverse + rows_without_last_accessed(rows)
    when "last_accessed_asc"
      sort_rows_by_last_accessed(rows) + rows_without_last_accessed(rows)
    else
      rows
    end
  end

  def sort_rows_by_last_accessed(rows)
    rows_with_last_accessed(rows).sort_by do |row|
      Time.zone.parse(row[:last_accessed_at])
    end
  end

  def rows_with_last_accessed(rows)
    rows.select { _1[:last_accessed_at].present? }
  end

  def rows_without_last_accessed(rows)
    rows.reject { _1[:last_accessed_at].present? }
  end

  def document_usage_report_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      @report_hash[:documents].each do |row|
        csv << document_usage_report_csv_row(row)
      end
    end
  end

  def document_usage_report_csv_row(row)
    [
      row[:title],
      row[:slug],
      helpers.document_category_label(row[:category]),
      helpers.document_kind_label(row[:document_kind]),
      helpers.document_visibility_policy_label(row[:visibility_policy]),
      helpers.document_usage_report_usage_badge_label(row),
      row[:view_count],
      row[:download_count],
      row[:read_confirmation_count],
      row[:last_accessed_at].presence.to_s
    ]
  end

  def document_usage_report_csv_filename
    project_token = @report_hash.dig(:project, :code).presence || @report_hash.dig(:project, :public_id)

    "document-usage-report-#{project_token}-#{Date.current.iso8601}.csv"
  end

  def document_usage_report_metadata
    filters = document_usage_report_export_filters

    {
      exported_at: Time.current.iso8601,
      report_type: "document_usage_report",
      export_scope: "current_project_usage_report",
      description: "CSV export と同じ案件・期間・利用状況・検索・並び順で集計した文書利用状況です。",
      filters:,
      ignored_filters: @ignored_date_filters.map(&:to_s),
      row_count: @report_hash[:documents].size,
      summary: document_usage_report_export_summary(filters)
    }
  end

  def document_usage_report_export_filters
    {
      project_id: @selected_project.id,
      project: {
        code: @report_hash.dig(:project, :code),
        name: @report_hash.dig(:project, :name),
        public_id: @report_hash.dig(:project, :public_id)
      },
      q: @query.presence,
      usage_filter: @usage_filter,
      usage_filter_label: helpers.document_usage_report_filter_label(@usage_filter),
      sort_order: @sort_order,
      sort_order_label: helpers.document_usage_report_sort_label(@sort_order),
      from: @from_date&.iso8601,
      to: @to_date&.iso8601,
      period_label: helpers.document_usage_report_period_label(@from_date, @to_date)
    }.compact
  end

  def document_usage_report_export_summary(filters)
    [
      "文書利用状況",
      "案件: #{filters.dig(:project, :code)} / #{filters.dig(:project, :name)}",
      "期間: #{filters[:period_label]}",
      "利用状況: #{filters[:usage_filter_label]}",
      "並び順: #{filters[:sort_order_label]}",
      "検索: #{filters[:q].presence || 'なし'}",
      "行数: #{@report_hash[:documents].size}件"
    ].join(" / ")
  end
end
