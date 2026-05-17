class AddDocumentSetToDocumentDeliveryLogs < ActiveRecord::Migration[8.1]
  def change
    add_reference :document_delivery_logs, :document_set, foreign_key: true
  end
end
