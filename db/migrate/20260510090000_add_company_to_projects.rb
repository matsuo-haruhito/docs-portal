class AddCompanyToProjects < ActiveRecord::Migration[8.1]
  def change
    add_reference :projects, :company, null: true, foreign_key: true
  end
end
