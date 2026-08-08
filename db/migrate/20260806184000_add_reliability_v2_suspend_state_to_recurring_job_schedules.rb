class AddReliabilityV2SuspendStateToRecurringJobSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :recurring_job_schedules,
      :enabled_before_reliability_v2_suspend,
      :boolean,
      comment: "信頼性V2停止前の有効状態"
  end
end
