class AccessLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :company, optional: true
  belongs_to :project, optional: true
  belongs_to :document, optional: true
  belongs_to :document_version, optional: true

  enum :action_type, { view: 0, download: 1 }

  before_validation :ensure_public_id, on: :create

  validates :public_id, presence: true, uniqueness: true
  validates :target_type, :accessed_at, presence: true

  private

  def ensure_public_id
    self.public_id ||= "alog_#{SecureRandom.urlsafe_base64(16)}"
  end
end
