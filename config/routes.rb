Rails.application.routes.draw do
  root "projects#index"

  mount RailsTablePreferences::Engine, at: "/rails_table_preferences"

  if Rails.env.development?
    get "capture_login", to: "sessions#capture_login"
  end

  post "external_folder_sync_webhooks/google_drive", to: "external_folder_sync_webhooks#google_drive"
  post "external_folder_sync_webhooks/sharepoint", to: "external_folder_sync_webhooks#sharepoint"
  get "external_folder_sync_webhooks/sharepoint", to: "external_folder_sync_webhooks#sharepoint"

  get "dashboard", to: "dashboard#show", as: :dashboard
  get "documents/project_search", to: "accessible_documents#project_search", as: :project_search_documents
  get "documents/selected_project", to: "accessible_documents#selected_project", as: :selected_project_documents
  get "documents", to: "accessible_documents#index", as: :documents
  resources :consents, only: %i[index new create], param: :public_id
  resources :document_approval_requests, only: %i[index show update], param: :public_id do
    post :cancel, on: :member
  end
  resources :document_delivery_logs, only: %i[index show update], param: :public_id do
    get :failure_alert_handoff, on: :collection
  end
  resource :session, only: %i[new create destroy]
  resources :document_bookmarks, only: %i[index create destroy], param: :public_id do
    post :move_to_favorite, on: :member
  end
  resources :read_confirmations, only: %i[create destroy], param: :public_id
  resources :access_requests, only: %i[index create], param: :public_id do
    post :cancel, on: :member
  end

  namespace :admin do
    root "dashboard#index"
    resource :api_specification, only: [:show] do
      post "retry_build", to: "api_specifications#retry_build", as: :retry_build
      get "site(/*site_path)", to: "api_specifications#site", as: :site, format: false
    end
    get "model_browser", to: "model_browsers#index", as: :model_browser
    get "model_browser/:model_key", to: "model_browsers#show", as: :model_browser_model
    resource :missing_document_files, only: [:show] do
      get :project_search
      get :selected_project
    end

    resources :companies, except: %i[show new], param: :public_id
    resources :users, except: %i[show new], param: :public_id
    resources :projects, except: %i[show new], param: :code do
      member do
        get "external_preview", to: "project_external_previews#show"
        get "external_preview/user_search", to: "project_external_previews#user_search", as: :external_preview_user_search
        get "external_preview/selected_user", to: "project_external_previews#selected_user", as: :selected_external_preview_user
        get "external_preview/company_search", to: "project_external_previews#company_search", as: :external_preview_company_search
        get "external_preview/selected_company", to: "project_external_previews#selected_company", as: :selected_external_preview_company
        get "permission_preview", to: "project_permission_previews#show"
        post "apply_template", to: "project_templates#create"
      end
    end
    resources :project_memberships, except: %i[show new], param: :public_id
    resources :consent_terms, except: %i[show new], param: :public_id
    resources :project_consent_settings, except: %i[show new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      get :consent_term_search, on: :collection
      get :selected_consent_term, on: :collection
    end
    resources :git_import_sources, except: %i[show new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      post :sync, on: :member
    end
    resources :git_import_runs, only: [:index] do
      get :project_search, on: :collection
      get :selected_project, on: :collection
    end
    resources :generated_file_events, only: %i[index show], param: :public_id do
      post :retry_dispatch, on: :member
      post :retry_failed, on: :collection
    end
    resources :generated_file_runs, only: %i[index show], param: :public_id do
      post :retry_run, on: :member
      post :retry_failed, on: :collection
    end
    resources :zip_imports, only: %i[new create show update], param: :public_id
    resources :file_upload_dry_runs, only: %i[index show update], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
    end
    resources :microsoft_graph_connections, except: %i[show new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
    end
    resources :recurring_job_schedules, only: %i[index show], param: :public_id do
      post :sync_definitions, on: :collection
      post :request_run, on: :member
    end
    get "external_folder_sync_oauth_connections/callback", to: "external_folder_sync_oauth_connections#callback", as: :callback_external_folder_sync_oauth_connections
    resources :external_folder_sync_sources, except: %i[new], param: :public_id do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      post :dry_run, on: :member
      post :apply, on: :member
      post :force_apply, on: :member
      post :enqueue, on: :member
      post :subscribe, on: :member
      post :recheck_metadata, on: :member
      delete :unsubscribe, on: :member
      resource :external_folder_sync_oauth_connection, only: %i[new destroy]
    end
    resources :documents, except: %i[show new], param: :public_id do
      get :lifecycle_handoff, on: :collection
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
    resources :document_permissions, except: %i[show new], param: :public_id do
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
    end
    resources :access_requests, only: %i[index update], param: :public_id do
      get :pending_handoff, on: :collection
    end
    resources :document_usage_reports, only: [:index] do
      get :project_search, on: :collection
      get :selected_project, on: :collection
    end
    resources :read_confirmations, only: [:index] do
      get :project_search, on: :collection
      get :selected_project, on: :collection
      get :company_search, on: :collection
      get :selected_company, on: :collection
      get :user_search, on: :collection
      get :selected_user, on: :collection
    end
  end

  resources :projects, only: [:index, :show], param: :code do
    get "document_tree", to: "projects#document_tree", as: :document_tree
    post "document_tree_all", to: "projects#document_tree_all", as: :document_tree_all, on: :member
    match "document_detail_tree", to: "projects#document_detail_tree", as: :document_detail_tree, on: :member, via: %i[get post]
    resource :ai_context, only: [:show], controller: "project_ai_contexts"
    get "site(/*site_path)", to: "project_sites#show", as: :site, format: false
    resource :document_zip, only: [:create], controller: "project_document_zips"
    resources :document_uploads, only: [:create]
    resources :document_sets, only: %i[index show], param: :public_id
    resources :document_catalogs, only: %i[index show], param: :public_id
    resources :documents, only: [:index, :show], param: :slug do
      resources :document_delivery_logs, only: %i[new create], param: :public_id
      resources :document_approval_requests, only: %i[index create], param: :public_id
      resources :document_review_comments, only: %i[create update], param: :public_id
    end
    resources :document_sets, only: [], param: :public_id do
      resources :document_delivery_logs, only: %i[new create], param: :public_id
    end
  end

  resources :document_versions, only: [:show], param: :public_id do
    resource :archive, only: [:show], controller: "document_version_archives"
    resource :quality_check, only: [:show], controller: "document_version_quality_checks"
    resource :rollback, only: [:create], controller: "document_version_rollbacks"
    resource :upload_review, only: [:create], controller: "document_version_upload_reviews"
    resources :document_review_comments, only: %i[create update], param: :public_id

    member do
      get :view, to: "document_views#show"
      get "site(/*site_path)", to: "document_sites#show", as: :site, format: false
    end
  end

  resources :document_files, only: [:show], param: :public_id do
    get "archive_entries/preview", to: "document_file_archive_entries#preview", as: :archive_entry_preview, on: :member
    get "archive_entries/download", to: "document_file_archive_entries#download", as: :archive_entry_download, on: :member
    get "assets/*asset_path", to: "document_files#asset", as: :asset, on: :member, format: false
  end

  namespace :api do
    namespace :internal do
      resources :artifact_imports, only: [:create]
      resources :file_uploads, only: [:create]
      resources :zip_uploads, only: [:create]
    end
  end
end
