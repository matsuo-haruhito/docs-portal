# db/migrate/20260429000200_add_public_id_to_application_tables.rb
require "securerandom"

class AddPublicIdToApplicationTables < ActiveRecord::Migration[8.1]
  TABLES = %i[
    companies
    users
    projects
    project_memberships
    documents
    document_versions
    document_files
    document_permissions
    publish_jobs
    access_logs
  ].freeze

  PREFIXES = {
    companies: "com",
    users: "usr",
    projects: "prj",
    project_memberships: "pmem",
    documents: "doc",
    document_versions: "ver",
    document_files: "file",
    document_permissions: "perm",
    publish_jobs: "pubjob",
    access_logs: "alog"
  }.freeze

  def up
    TABLES.each do |table_name|
      add_column table_name, :public_id, :string
    end

    TABLES.each do |table_name|
      backfill_public_ids!(table_name)
      change_column_null table_name, :public_id, false
      add_index table_name, :public_id, unique: true
    end
  end

  def down
    TABLES.reverse_each do |table_name|
      remove_index table_name, :public_id if index_exists?(table_name, :public_id)
      remove_column table_name, :public_id if column_exists?(table_name, :public_id)
    end
  end

  private

  def backfill_public_ids!(table_name)
    prefix = PREFIXES.fetch(table_name)

    select_all("SELECT id FROM #{quote_table_name(table_name)} WHERE public_id IS NULL").each do |row|
      public_id = generate_unique_public_id(table_name, prefix)

      execute <<~SQL.squish
        UPDATE #{quote_table_name(table_name)}
        SET public_id = #{quote(public_id)}
        WHERE id = #{row.fetch("id")}
      SQL
    end
  end

  def generate_unique_public_id(table_name, prefix)
    loop do
      public_id = "#{prefix}_#{SecureRandom.urlsafe_base64(12)}"
      exists = select_value(<<~SQL.squish)
        SELECT 1
        FROM #{quote_table_name(table_name)}
        WHERE public_id = #{quote(public_id)}
        LIMIT 1
      SQL

      return public_id unless exists
    end
  end
end
