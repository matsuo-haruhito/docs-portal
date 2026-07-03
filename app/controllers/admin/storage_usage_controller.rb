class Admin::StorageUsageController < Admin::BaseController
  before_action :require_admin_only!

  def document_files
    @document_file_storage_usage_detail = StorageUsageSummary.new.document_file_detail
  end

  def docs_sites
    @storage_area_detail = StorageUsageSummary.new.docs_site_detail
  end

  def imports
    @storage_area_detail = StorageUsageSummary.new.import_detail
  end
end
