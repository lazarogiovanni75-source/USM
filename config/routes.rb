require 'rails/application'

Rails.application.routes.draw do
  # PWA routes
  get '/manifest.json', to: 'pwa#manifest', defaults: { format: :json }
  get '/service-worker.js', to: 'pwa#service_worker', defaults: { format: :js }
  # Root path
  root "home#index"

  # API routes
  namespace :api do
    namespace :v1 do
      # Voice API endpoints
      post 'voice/generate', to: 'voice#generate'
      get 'voices', to: 'voice#voices'
      get 'voice/health', to: 'voice#health'
    end
  end

  # Authentication routes
  get 'sign_in', to: 'sessions#new', as: :new_user_session
  post 'sign_in', to: 'sessions#create', as: :user_session
  delete 'sign_out', to: 'sessions#destroy', as: :destroy_user_session
  
  # Additional session routes
  get 'devices', to: 'sessions#devices', as: :devices_session
  get 'sessions/:id', to: 'sessions#show', as: :session
  
  get 'sign_up', to: 'registrations#new', as: :new_user_registration
  post 'sign_up', to: 'registrations#create', as: :user_registration
  
  get 'forgot_password', to: 'identity/password_resets#new', as: :new_user_password
  post 'forgot_password', to: 'identity/password_resets#create', as: :user_password
  get 'reset_password/:sid', to: 'identity/password_resets#edit', as: :edit_user_password
  patch 'reset_password/:sid', to: 'identity/password_resets#update'
  
  get 'confirm_email/:sid', to: 'identity/email_verifications#show', as: :user_email_verification
  post 'confirm_email/:sid', to: 'identity/email_verifications#confirm'
  get 'resend_confirmation', to: 'identity/email_verifications#new', as: :new_user_email_verification
  get 'resend_confirmation/:sid', to: 'identity/email_verifications#resend', as: :identity_email_verification
  
  # Identity email management
  get 'emails', to: 'identity/emails#edit', as: :edit_identity_email
  patch 'emails', to: 'identity/emails#update'
  
  # Convenience aliases for navbar
  get 'sign_in', to: 'sessions#new', as: :sign_in
  get 'sign_up', to: 'registrations#new', as: :sign_up
  delete 'sign_out', to: 'sessions#destroy', as: :sign_out

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    get 'login', to: 'sessions#new', as: :login
    post 'login', to: 'sessions#create'
    delete 'logout', to: 'sessions#destroy'
    resources :administrators, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :users, only: [:index, :show, :destroy]
    resources :accounts, only: [:index, :show, :edit, :update]
    resources :admin_oplogs, only: [:index, :show]
    
    # Dedicated password change route for current admin
    get 'password/change', to: 'accounts#change_password', as: :change_password
    patch 'password/change', to: 'accounts#update_password'
  end

  # Application routes
  resource :profile, only: [:show, :edit] do
    member do
      get 'edit_password', to: 'profiles#edit_password'
      patch 'update_password', to: 'profiles#update_password'
    end
  end
  resources :dashboards, only: [:index]
  resources :campaigns
  resources :contents do
    member do
      get 'preview'
      get 'optimize'
    end
  end
  resources :social_accounts
  resources :scheduled_posts do
    member do
      post 'publish_now'
      post 'optimize'
      get 'predictions'
    end
    collection do
      post 'bulk_update'
      post 'batch_schedule'
      get 'optimal_times'
      get 'engagement_predictions'
      get 'scheduling_analytics'
    end
  end
  resources :voice_commands, only: [:index, :show, :create]
  resources :performance_metrics, only: [:index]
  
  # Calendar Management System
  resources :calendar, only: [:index] do
    collection do
      post 'optimize'
      post 'reschedule'
      get 'suggestions'
      post 'bulk_schedule'
    end
  end
  
  # AI & Voice features routes
  resources :ai_chat, only: [:index, :show, :create] do
    collection do
      post 'send_message'
      post 'suggest_content'
    end
  end
  
  resources :voice_controller, only: [] do
    collection do
      post 'generate_voice'
      post 'speech_to_text'
      get 'get_voices'
      post 'save_voice_settings'
    end
  end
  
  # Content & Scheduling features routes
  resources :content_creation, only: [:index] do
    collection do
      post 'create_draft'
      patch 'update_draft'
      post 'generate_content'
      post 'publish_content'
      post 'schedule_content'
    end
  end
  
  resources :prompt_templates, only: [:index, :create, :update, :destroy]
  
  # Draft Management System
  resources :drafts do
    member do
      post 'convert_to_content'
      post 'duplicate'
    end
    collection do
      post 'bulk_actions'
      get 'search'
    end
  end
  
  # Content Template System
  resources :content_templates, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      post 'duplicate'
      post 'process'
      post 'preview'
    end
    collection do
      get 'popular'
      get 'categories'
      get 'search'
    end
  end
  
  # Queue-Based Publishing System
  resources :publish_queues do
    member do
      post 'process'
      post 'cancel_item'
      post 'retry_item'
    end
    collection do
      post 'clear_completed'
      post 'pause_queue'
      post 'resume_queue'
      post 'optimize_queue'
      get 'queue_status'
      get 'queue_analytics'
    end
  end
  
  resources :content_suggestions, only: [:index, :show]
  resources :draft_contents, only: [:index, :show, :destroy]
  
  # Engagement Analytics System
  resources :engagement_analytics, only: [:index] do
    collection do
      get 'overview'
      get 'posting_times'
      get 'content_performance'
      get 'audience_growth'
      get 'suggestions'
      get 'export_data'
      get 'compare_periods'
    end
  end
  
  # Post Performance Overview System
  resources :post_performance_overview, only: [:index, :show] do
    member do
      get 'post_insights'
    end
    collection do
      post 'generate_report'
      get 'compare_posts'
      get 'export_data'
      get 'bulk_analytics'
    end
  end
  
  # Automation & Analytics features routes
  resources :automation_rules, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    member do
      post 'test_rule'
      post 'toggle_status'
    end
    collection do
      post 'create_from_template'
      post 'bulk_actions'
      get 'export_rules'
    end
  end
  
  resources :auto_response_triggers, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    member do
      post 'test_trigger'
      post 'toggle_status'
    end
    collection do
      post 'create_from_template'
    end
  end
  
  resources :scheduled_tasks, only: [:index]

  resources :scheduled_ai_tasks, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    member do
      post 'execute_now'
      post 'toggle_status'
      post 'pause_task'
      post 'resume_task'
    end
    collection do
      post 'create_from_template'
      post 'execute_all_due'
      post 'bulk_actions'
      get 'results'
    end
  end
  get 'pwa/manifest', to: 'pwa#manifest'
  get 'pwa/service-worker', to: 'pwa#service_worker'
  post 'pwa/install-prompt', to: 'pwa#install_prompt'
  get 'pwa/update-available', to: 'pwa#update_available'
  get 'pwa/status', to: 'pwa#status'
  resources :trend_analyses, only: [:index, :show] do
    collection do
      get 'analyze_period'
      get 'export_trends'
    end
  end
  
  resources :pages, only: [:show] do
    collection do
      get 'features'
      get 'pricing'
      get 'about'
    end
  end

  # Health check endpoint
  get 'health', to: 'application#health'
end