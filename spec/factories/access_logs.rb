FactoryBot.define do
  factory :access_log do
    action_type { :view }
    target_type { "document" }
    accessed_at { Time.current }
  end
end
