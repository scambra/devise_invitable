RailsApp::Application.routes.draw do
  devise_for :users
  devise_for :validating_users
  root :to => 'home#index'
end
