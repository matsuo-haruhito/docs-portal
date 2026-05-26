class Admin::DocumentUsageReportsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @projects = Project.order(:name, :id)
    @selected_project = selected_project
    @usage_filter = usage_filter_param
    @sort_order = sort_order_param
    @report_hash = build_report_hash(@selected_project) if @selected_project
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

  def normalized_enum_param(value, allowed:, default:)
    candidate = Array.wrap(value).compact_blank.first

    allowed.include?(candidate) ? candidate : default
  end

  def build_report_hash(project)
    result = DocumentUsageReport.new(project:).call
    report_hash = DocumentUsageReportHash.new(result).call

    report_hash.merge(documents: sort_rows(filter_rows(report_hash[:documents])))
  end

  def filter_rows(rows)
    case @usage_filter
    when "used"
      rows.select { _1[:used] }
    when "unused"
      rows.reject { _1[:used] }
    else
      rows
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
end
