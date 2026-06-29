Rails.application.routes.draw do
  root "dashboard#index"

  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token
  resources :password_reset_requests, only: %i[new create]
  resources :user_settings, only: %i[show update]
  resources :projects, only: %i[index show], param: :code do
    resources :documents, only: %i[show], param: :slug do
      resources :document_files, only: %i[show], param: :public_id
      resources :document_versions, only: %i[show], param: :public_id
      resources :manual_document_uploads, only: %i[create]
    end
  end
  resources :documents, only: %i[index]
  resources :document_versions, only: %i[show], param: :public_id
  resources :document_files, only: %i[show], param: :public_id
  resources :consents, only: %i[index new create]
  resources :access_requests, only: %i[index new create update], param: :public_id
  resources :document_delivery_logs, only: %i[index show], param: :public_id

  namespace :api do
    namespace :internal do
      resources :file_uploads, only: %i[create update], param: :public_id
    end
  end

  namespace :admin do
    root "dashboard#index"
    resources :projects, except: %i[show new], param: :code
    resources :companies, except: %i[show new], param: :domain
    resources :users, except: %i[show new], param: :public_id
    resources :consent_terms, except: %i[show new], param: :public_id
    resources :documents, except: %i[show new], param: :public_id do
      get :lifecycle_handoff, on: :collection
      get :project_search, on: :collection
      get :selected_project, on: :collection
      patch :archive, on: :member
      patch :restore, on: :member
    end
    resources :bulk_edit_dry_runs, only: %i[new create show update], param: :public_id do
      post :handoff, on: :collection
    end
    resources :document_sets, except: %i[show new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      get :document_search, on: :collection
      get :document_version_search, on: :collection
    end
    resources :document_catalogs, except: %i[show new], param: :public_id
    resources :document_permissions, except: %i[show new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      get :document_search, on: :collection
      get :selected_document, on: :collection
    end
    resources :webhook_endpoints, except: %i[show new], param: :public_id
    resources :webhook_deliveries, only: %i[index show], param: :public_id do
      get :webhook_endpoint_search, on: :collection
      get :selected_webhook_endpoint, on: :collection
      post :retry_dispatch, on: :member
      post :retry_failed, on: :collection
    end
    resources :access_logs, only: [:index] do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      get :company_search, on: :collection
      get :selected_company, on: :collection
      get :user_search, on: :collection
      get :selected_user, on: :collection
      get :export_metadata, on: :collection
    end
    resources :settings, only: %i[index update]
    resources :generated_files, only: %i[index show], param: :public_id do
      post :retry_import, on: :member
      post :retry_build, on: :member
      post :retry_failed_imports, on: :collection
      post :retry_failed_builds, on: :collection
      get :run_failure_handoff, on: :collection
    end
    resources :generated_file_runs, only: %i[index show], param: :public_id
    resources :generated_file_events, only: %i[index update], param: :public_id do
      post :retry_dispatch, on: :member
      post :retry_failed, on: :collection
    end
    resources :generated_file_schedules, only: %i[index create update], param: :public_id do
      post :pause, on: :member
      post :resume, on: :member
      post :run_now, on: :member
    end
    resources :git_import_sources, except: %i[show new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
    end
    resources :git_import_runs, only: %i[index show], param: :public_id do
      post :retry, on: :member
      post :retry_failed, on: :collection
    end
    resources :zip_imports, only: %i[new create show], param: :public_id do
      post :apply, on: :member
    end
    resources :external_folder_syncs, only: %i[index show], param: :public_id do
      post :dry_run, on: :collection
      post :apply, on: :member
      get :failure_handoff, on: :collection
    end
    resources :microsoft_graph_connections, except: %i[show new], param: :public_id
    resources :document_usage_reports, only: %i[index]
    resources :read_confirmations, only: %i[index]
    resources :document_activity_summaries, only: %i[index]
    resources :document_activity_exports, only: %i[index]
    resources :ai_context_exports, only: %i[index show create], param: :public_id
  end
end
