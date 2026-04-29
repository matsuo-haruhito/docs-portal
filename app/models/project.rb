class Project < ApplicationRecord
  include ProjectAccess

  has_many :documents, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :users, through: :project_memberships

  validates :code, :name, presence: true
  validates :code, uniqueness: true
end
