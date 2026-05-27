class WebhookEndpoint < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "whend"

  EVENT_TYPES = %w[
    document_updated
    document_published
    import_completed
    import_failed
    review_approved
    qa_posted
    qa_answered
  ].freeze

  has_many :webhook_deliveries, dependent: :destroy

  validates :name, :target_url, presence: true
  validates :target_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validate :event_types_are_supported
  validate :headers_json_is_a_hash

  scope :active, -> { where(active: true) }
  scope :subscribed_to, ->(event_type) { active.select { |endpoint| endpoint.subscribed_to?(event_type) } }

  def to_param
    public_id
  end

  def subscribed_to?(event_type)
    normalized_event_types.include?(event_type.to_s)
  end

  def normalized_event_types
    Array(event_types).map(&:to_s).uniq
  end

  private

  def event_types_are_supported
    unsupported = normalized_event_types - EVENT_TYPES
    return if unsupported.empty?

    errors.add(:event_types, "contains unsupported values: #{unsupported.join(', ')}")
  end

  def headers_json_is_a_hash
    return if headers_json.is_a?(Hash)

    errors.add(:headers_json, "must be a hash")
  end
end