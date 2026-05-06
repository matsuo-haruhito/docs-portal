FactoryBot.define do
  factory :consent_term do
    title { "Portal Terms" }
    body { "Please agree before viewing documents." }
    version_label { "v1" }
    active { true }
    consent_scope { :global }
    requirement_timing { :first_view }
  end

  factory :user_consent do
    association :user
    association :consent_term
    consented_at { Time.current }
    consent_term_version_label { consent_term.version_label }
  end

  factory :project_consent_setting do
    association :project
    association :consent_term
    required_on { :first_access }
    enabled { true }
  end
end
