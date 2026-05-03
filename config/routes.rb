Rails.application.routes.draw do
  root "projects#index"

  resource :session, only: %i[new create destroy]

  namespace :admin do
    root "dashboard#index"

    resources :companies, except: %i[show new]
    resources :users, except: %i[show new]
    resources :projects, except: %i[show new]
    resources :project_memberships, except: %i[show new]
    resources :documents, except: %i[show new]
    resources :document_permissions, except: %i[show new]
    resources :access_logs, only: [:index]
  end

  resources :projects, only: [:index, :show], param: :code do
    get "site(/*site_path)", to: "project_sites#show", as: :site, format: false
    resource :document_zip, only: [:create], controller: "project_document_zips"
    resources :documents, only: [:index, :show], param: :slug
  end

  resources :document_versions, only: [:show], param: :public_id do
    resource :archive, only: [:show], controller: "document_version_archives"

    member do
      get :view, to: "document_views#show"
      get "site(/*site_path)", to: "document_sites#show", as: :site, format: false
    end
  end

  resources :document_files, only: [:show], param: :public_id

  namespace :api do
    namespace :internal do
      resources :doc_imports, only: [:create]
    end
  end
end
