class Company < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "com"

  has_many :users, dependent: :restrict_with_exception
  has_many :document_permissions, dependent: :destroy

  before_validation :normalize_domain

  validates :domain, presence: true
  validates :domain, uniqueness: true

  def display_name
    name.presence || domain
  end

  private

  def normalize_domain
    self.domain = domain.to_s.strip.delete_prefix("@").downcase.presence
  end
end
