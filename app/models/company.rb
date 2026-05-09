class Company < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "com"

  has_many :users, dependent: :restrict_with_exception
  has_many :document_permissions, dependent: :destroy

  before_validation :normalize_domain

  validates :domain, presence: true
  validates :domain, uniqueness: true

  def self.upsert_all(attributes, **options)
    normalized_attributes = attributes.map do |attribute|
      next attribute unless attribute.key?(:code) && !attribute.key?(:domain)

      attribute.except(:code).merge(domain: attribute[:code])
    end
    options[:unique_by] = :index_companies_on_domain if options[:unique_by].to_s == "index_companies_on_code"

    super(normalized_attributes, **options)
  end

  def code
    domain
  end

  def code=(value)
    self.domain = value
  end

  def display_name
    name.presence || domain
  end

  private

  def normalize_domain
    self.domain = domain.to_s.strip.delete_prefix("@").downcase.presence
  end
end
