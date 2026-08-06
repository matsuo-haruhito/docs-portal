class AddCancellationReasonToAccessRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :access_requests, :cancellation_reason, :text, comment: "取消理由"
  end
end
