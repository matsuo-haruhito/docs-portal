Rails.application.routes.append do
  post "/api/internal/artifact_imports", to: "api/internal/artifact_imports#create"
end
