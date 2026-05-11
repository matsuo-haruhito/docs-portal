Rails.application.routes.draw do
  root "projects#index"

  if Rails.env.development?
    get "capture_login", to: "sessions#capture_login"
  end

  get "dashboard", to: "dashboard#show", as: :dashboard
  resources :consents, only: %i[index new create], param: :public_id
  resources :document_approval_requests, only: %i[index show update], param: :public_id do
    post :cancel, on: :member
  end
  resources :document_delivery_logs, only: %i[index show update], param: :public_id
  resource :session, only: %i[new create destroy]
  resources :document_bookmarks, only: %i[index create destroy], param: :public_id
  resources :read_confirmations, only: %i[create destroy], param: :public_id
  resources :access_requests, only: %i[index create], param: :public_id do
    post :cancel, on: :member
  end

  namespace :admin do
    root "dashboard#index"
    resource :api_specification, only: [:show] do
      get "site(/*site_path)", to: "api_specifications#site", as: :site, format: false
    end
    get "model_browser", to: "model_browsers#index", as: :model_browser
    get "model_browser/:model_key", to: "model_browsers#show", as: :model_browser_model

    resources :companies, except: %i[show new]
    resources :users, except: %i[show new]
    resources :projects, except: %i[show new] do
      get "external_preview", to: "project_external_previews#show", on: :member
      get "permission_preview", to: "project_permission_previews#show", on: :member
      post "apply_template", to: "project_templates#create", on: :member
    end
    resources :project_memberships, except: %i[show new]
    resources :consent_terms, except: %i[show new]
    resources :project_consent_settings, except: %i[show new]
    resources :git_import_sources, except: %i[show new] do
      post :sync, on: :member
    end
    resources :git_import_runs, only: [:index]
    resources :microsoft_graph_connections, except: %i[show new]
    get "external_folder_sync_oauth_connections/callback", to: "external_folder_sync_oauth_connections#callback", as: :callback_external_folder_sync_oauth_connections
    resources :external_folder_sync_sources, except: %i[new] do
      post :dry_run, on: :member
      post :apply, on: :member
      post :enqueue, on: :member
      resource :external_folder_sync_oauth_connection, only: %i[new destroy]
    end
    resources :documents, except: %i[show new] do
      patch :archive, on: :member
      patch :restore, on: :member
    end
    resources :bulk_edit_dry_runs, only: %i[new create show update], param: :public_id
    resources :document_sets, except: %i[show new]
    resources :document_permissions, except: %i[show new]
    resources :webhook_endpoints, except: %i[show new]
    resources :access_logs, only: [:index]
    resources :access_requests, only: %i[index update], param: :public_id
    resources :document_usage_reports, only: [:index]
  end

  resources :projects, only: [:index, :show], param: :code do
    get "document_tree", to: "projects#document_tree", as: :document_tree
    post "document_tree_all", to: "projects#document_tree_all", as: :document_tree_all, on: :member
    match "document_detail_tree", to: "projects#document_detail_tree", as: :document_detail_tree, on: :member, via: %i[get post]
    resource :ai_context, only: [:show], controller: "project_ai_contexts"
    get "site(/*site_path)", to: "project_sites#show", as: :site, format: false
    resource :document_zip, only: [:create], controller: "project_document_zips"
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
    resources :document_review_comments, only: %i[create update], param: :public_id

    member do
      get :view, to: "document_views#show"
      get "site(/*site_path)", to: "document_sites#show", as: :site, format: false
    end
  end

  resources :document_files, only: [:show], param: :public_id do
    get "assets/*asset_path", to: "document_files#asset", as: :asset, on: :member, format: false
  end

  namespace :api do
    namespace :internal do
      resources :doc_imports, only: [:create]
      resources :zip_imports, only: [:create]
    end
  end
end
