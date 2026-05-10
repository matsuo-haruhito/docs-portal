class ImportRouteSetting < ApplicationRecord
  ROUTE_KEYS = %w[
    git
    zip
    webhook
    external_sample
  ].freeze

  SETTING_KEYS = %w[
    dry_run_policy
  ].freeze

  DRY_RUN_POLICIES = %w[
    require_confirmation
    auto_confirm
  ].freeze

  belongs_to :project, optional: true

  validates :route_key, presence: true, inclusion: { in: ROUTE_KEYS }
  validates :setting_key, presence: true, inclusion: { in: SETTING_KEYS }
  validates :setting_value, presence: true
  validates :setting_key, uniqueness: { scope: %i[project_id route_key] }
  validate :setting_value_allowed_for_key

  scope :global_defaults, -> { where(project_id: nil) }

  def self.resolve(project:, route_key:, setting_key:, default: nil)
    project_setting = where(project:, route_key:, setting_key:).first if project
    return project_setting.setting_value if project_setting

    global_setting = global_defaults.where(route_key:, setting_key:).first
    return global_setting.setting_value if global_setting

    default
  end

  def self.dry_run_policy_for(project:, route_key:, default: "require_confirmation")
    resolve(project:, route_key:, setting_key: "dry_run_policy", default:)
  end

  private

  def setting_value_allowed_for_key
    case setting_key
    when "dry_run_policy"
      errors.add(:setting_value, "is not included in the list") unless DRY_RUN_POLICIES.include?(setting_value)
    end
  end
end
