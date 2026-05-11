class DocumentFileMicrosoftGraphPreviewUploadCleanup
  class Error < StandardError; end

  def initialize(upload:)
    @upload = upload
  end

  def call
    MicrosoftGraphClient.new(connection: upload.microsoft_graph_connection).delete_item(item_id: upload.drive_item_id)
    upload.update!(deleted_at: Time.current, last_error_message: nil)
  rescue MicrosoftGraphClient::Error => e
    upload.update!(last_error_message: e.message)
    raise
  end

  private

  attr_reader :upload
end
