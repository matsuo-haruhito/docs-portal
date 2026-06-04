class Admin::MissingDocumentFilesController < Admin::BaseController
  DETAIL_LIMIT = 100

  before_action :require_admin_only!

  def show
    @display_limit = DETAIL_LIMIT
    @document_file_health = DocumentFileHealthCheck.new.call(limit: DETAIL_LIMIT)
  end
end
