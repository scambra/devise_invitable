RailsApp::Application.routes.draw do
  devise_for :users
  devise_scope :user do
    resource :free_invitation, :only => [:new, :create]
  end
  root :to => 'home#index'
end
