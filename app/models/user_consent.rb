class UserConsent < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "ucn"

  belongs_to :user
  belongs_to :consent_term
  belongs_to :target, polymorphic: true, optional: true

  validates :consented_at, presence: true
  validates :consent_term_id, uniqueness: { scope: %i[user_id target_type target_id] }

  before_validation :set_consented_at, on: :create

  def to_param
    public_id
  end

  private

  def set_consented_at
    self.consented_at ||= Time.current
  end
end
