Rails.application.routes.append do
  post "/api/internal/artifact_imports", to: "api/internal/artifact_imports#create"
  post "/api/internal/file_uploads", to: "api/internal/manual_uploads#create"
  post "/api/internal/zip_uploads", to: "api/internal/zip_uploads#create"
end
