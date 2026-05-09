class UseDomainForCompaniesAndOptionalUserNames < ActiveRecord::Migration[8.1]
  def up
    rename_index :companies, :index_companies_on_code, :index_companies_on_domain
    rename_column :companies, :code, :domain

    execute <<~SQL.squish
      UPDATE companies
      SET domain = lower(trim(leading '@' from trim(domain)))
      WHERE domain IS NOT NULL
    SQL

    change_column_null :companies, :name, true
    change_column_null :users, :name, true
    change_column_default :users, :name, from: "", to: nil
  end

  def down
    change_column_default :users, :name, from: nil, to: ""
    execute <<~SQL.squish
      UPDATE users
      SET name = ''
      WHERE name IS NULL
    SQL
    change_column_null :users, :name, false

    execute <<~SQL.squish
      UPDATE companies
      SET name = domain
      WHERE name IS NULL
    SQL
    change_column_null :companies, :name, false

    rename_column :companies, :domain, :code
    rename_index :companies, :index_companies_on_domain, :index_companies_on_code
  end
end
