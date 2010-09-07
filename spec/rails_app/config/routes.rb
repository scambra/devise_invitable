Rails.application.routes.draw do
  # Users scope
  devise_for :users
  resource :user, :only => [:edit, :update], :path => 'account'#, :as => 'account'
  root :to => "home#index"
end