namespace :ai_usecases do
  desc "Generate AI usecase decision flow markdown and PlantUML from YAML DSL"
  task generate_flow: :environment do
    ruby Rails.root.join("bin", "generate_ai_usecase_flow").to_s
  end
end
