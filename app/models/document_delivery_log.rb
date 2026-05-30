class DocumentDeliveryLog < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "ddl"

  EMAIL_ADDRESS_PATTERN = /\A[^@\s]+@[^@\s]+\z/.freeze
  ADDRESS_FIELDS = %i[to_addresses cc_addresses bcc_addresses].freeze

  belongs_to :project
  belongs_to :document, optional: true
  belongs_to :document_set, optional: true
  belongs_to :sender, class_name: "User"

  enum :delivery_type, {
    portal_link: 0,
    shared_link: 1,
    attachment: 2,
    zip_attachment: 3
  }

  enum :status, {
    draft: 0,
    sent: 1,
    failed: 2
  }

  validates :to_addresses, :subject, :body, presence: true
  validates :delivery_type, :status, presence: true
  validate :document_or_set_presence
  validate :address_format

  before_validation :normalize_address_fields
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def to_param
    public_id
  end

  def recipients
    parse_addresses(to_addresses)
  end

  def cc_recipients
    parse_addresses(cc_addresses)
  end

  def bcc_recipients
    parse_addresses(bcc_addresses)
  end

  private

  def document_or_set_presence
    return if document.present? || document_set.present?

    errors.add(:base, "document or document_set must be present")
  end

  def address_format
    ADDRESS_FIELDS.each do |field|
      parse_addresses(public_send(field)).each do |address|
        errors.add(field, :invalid) unless EMAIL_ADDRESS_PATTERN.match?(address)
      end
    end
  end

  def normalize_address_fields
    self.to_addresses = normalize_addresses(to_addresses)
    self.cc_addresses = normalize_addresses(cc_addresses)
    self.bcc_addresses = normalize_addresses(bcc_addresses)
  end

  def normalize_addresses(value)
    parse_addresses(value).join(", ").presence
  end

  def parse_addresses(value)
    value.to_s
      .split(/[;,\n]/)
      .map { _1.strip.downcase }
      .reject(&:blank?)
      .uniq
  end
end