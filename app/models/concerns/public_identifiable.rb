require "securerandom"

module PublicIdentifiable
  extend ActiveSupport::Concern

  included do
    class_attribute :public_id_prefix_value, instance_writer: false

    before_validation :ensure_public_id, on: :create

    validates :public_id, presence: true, uniqueness: true
    validate :validate_public_id_prefix_configuration
  end

  class_methods do
    def public_id_prefix(value = nil)
      self.public_id_prefix_value = value if value
      public_id_prefix_value
    end
  end

  private

  def ensure_public_id
    return if public_id.present?

    prefix = self.class.public_id_prefix
    raise "#{self.class.name} public_id_prefix is not configured" if prefix.blank?

    self.public_id = generate_unique_public_id(prefix)
  end

  def generate_unique_public_id(prefix)
    loop do
      candidate = "#{prefix}_#{SecureRandom.urlsafe_base64(12)}"
      return candidate unless self.class.exists?(public_id: candidate)
    end
  end

  def validate_public_id_prefix_configuration
    return if self.class.public_id_prefix.present?

    errors.add(:public_id, "prefix is not configured")
  end
end
