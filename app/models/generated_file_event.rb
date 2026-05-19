require "pathname"

class GeneratedFileEvent < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "gfe"

  enum :status, {
    pending: 0,
    processing: 1,
    processed: 2,
    failed: 3
  }

  validates :event_key, :path, :operation, :scheduled_at, :last_seen_at, presence: true
  validate :path_must_be_safe_relative_path

  scope :due, ->(at = Time.current) { pending.where(scheduled_at: ..at) }

  def self.build_event_key(path:, operation:, event_source: nil)
    normalized_path = Pathname(path.to_s.strip.tr("\\", "/")).cleanpath.to_s.delete_prefix("./")
    normalized_operation = operation.to_s.presence || "update"
    [normalized_path, normalized_operation, event_source.to_s].join(":")
  end

  def mark_processed!
    update!(status: :processed, processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(error)
    update!(status: :failed, error_message: error.to_s, processed_at: Time.current)
  end

  private

  def path_must_be_safe_relative_path
    return if path.blank?

    raw_path = path.to_s.strip.tr("\\", "/")
    normalized_path = Pathname(raw_path).cleanpath.to_s.delete_prefix("./")
    return unless unsafe_relative_path?(raw_path) || unsafe_relative_path?(normalized_path)

    errors.add(:path, "must be a safe relative path")
  end

  def unsafe_relative_path?(value)
    value.blank? ||
      value == "." ||
      value == ".." ||
      value.start_with?("/") ||
      value.match?(%r{\A[A-Za-z]:/}) ||
      value.split("/").include?("..")
  end
end
