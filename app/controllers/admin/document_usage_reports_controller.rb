require "csv"

class Admin::DocumentUsageReportsController < Admin::BaseController
  before_action :require_admin_only!

  DOCUMENT_USAGE_QUERY_MAX_LENGTH = 100

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
    @projects = Project.order(:name, :id)
    @selected_project = selected_project
    @usage_filter = usage_filter_param
    @sort_order = sort_order_param
    @query = query_param
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
    end
  end

  private

  def selected_project
    return if params[:project_id].blank?

    @projects.find_by(id: params[:project_id])
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
    nil
  end

  def normalized_enum_param(value, allowed:, default:)
    candidate = Array.wrap(value).compact_blank.first

    allowed.include?(candidate) ? candidate : default
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
end
