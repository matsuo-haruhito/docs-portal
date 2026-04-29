# Fix for access_logs primary key sequence
# The seed data sets explicit IDs but the PostgreSQL sequence wasn't updated

class FixAccessLogsSequence < ActiveRecord::Migration[8.0]
  def up
    # Get the maximum ID from access_logs and set the sequence to that value + 1
    execute <<~SQL.squish
      SELECT setval('access_logs_id_seq', COALESCE((SELECT MAX(id) FROM access_logs), 0) + 1, true);
    SQL
  end

  def down
    # No rollback needed for sequence fix
  end
end