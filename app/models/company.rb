class Company < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "com"

  has_many :users, dependent: :restrict_with_exception
  has_many :document_permissions, dependent: :destroy

  validates :name, :code, presence: true
  validates :code, uniqueness: true
end
