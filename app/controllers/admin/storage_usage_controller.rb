require "csv"

class Admin::StorageUsageController < Admin::BaseController
  DOCUMENT_FILE_CSV_HEADERS = [
    "scope_status",
    "total_document_files",
    "displayed_document_files",
    "display_limit",
    "missing_document_files",
    "project_code",
    "project_name",
    "document_title",
    "document_slug",
    "file_name",
    "safe_relative_path",
    "file_count",
    "missing_file_count",
    "bytes",
    "human_size",
    "latest_updated_at",
    "read_only_note"
  ].freeze
  DOCUMENT_FILE_CSV_READ_ONLY_NOTE = "read-only handoff only; not a repair, delete, retention, billing, quota, or GCS policy decision".freeze

  before_action :require_admin_only!

  def document_files
    @document_file_storage_usage_detail = StorageUsageSummary.new.document_file_detail

    respond_to do |format|
      format.html
      format.csv do
        send_data document_file_storage_usage_csv,
                  filename: document_file_storage_usage_csv_filename,
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def docs_sites
    @storage_area_detail = StorageUsageSummary.new.docs_site_detail
  end

  def imports
    @storage_area_detail = StorageUsageSummary.new.import_detail
  end

  private

  def document_file_storage_usage_csv
    CSV.generate(headers: true) do |csv|
      csv << DOCUMENT_FILE_CSV_HEADERS

      if @document_file_storage_usage_detail.entries.any?
        @document_file_storage_usage_detail.entries.each do |entry|
          csv << document_file_storage_usage_csv_row(entry)
        end
      else
        csv << document_file_storage_usage_empty_csv_row
      end
    end
  end

  def document_file_storage_usage_csv_row(entry)
    [
      document_file_storage_usage_scope_status,
      @document_file_storage_usage_detail.total_count,
      @document_file_storage_usage_detail.entries.size,
      @document_file_storage_usage_detail.limit,
      @document_file_storage_usage_detail.missing_file_count,
      entry.project_code,
      entry.project_name,
      entry.document_title,
      entry.document_slug,
      entry.file_name,
      entry.relative_path,
      entry.file_count,
      entry.missing_file_count,
      entry.bytes,
      entry.human_size,
      entry.latest_updated_at&.iso8601,
      DOCUMENT_FILE_CSV_READ_ONLY_NOTE
    ]
  end

  def document_file_storage_usage_empty_csv_row
    [
      "no_entries",
      @document_file_storage_usage_detail.total_count,
      0,
      @document_file_storage_usage_detail.limit,
      @document_file_storage_usage_detail.missing_file_count,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      0,
      0,
      0,
      ActiveSupport::NumberHelper.number_to_human_size(0),
      nil,
      "No DocumentFile entries matched this bounded read-only handoff. This does not prove cleanup, retention, billing, quota, repair, or external storage status."
    ]
  end

  def document_file_storage_usage_scope_status
    @document_file_storage_usage_detail.limited? ? "limited_to_bounded_entries" : "complete_bounded_result"
  end

  def document_file_storage_usage_csv_filename
    "document-file-storage-detail-#{Date.current.iso8601}.csv"
  end
end
