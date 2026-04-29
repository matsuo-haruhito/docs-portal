class AccessLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :company, optional: true
  belongs_to :project, optional: true
  belongs_to :document, optional: true
  belongs_to :document_version, optional: true

  enum :action_type, { view: 0, download: 1 }

  validates :target_type, :accessed_at, presence: true
end
