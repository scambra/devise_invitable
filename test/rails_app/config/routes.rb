# frozen_string_literal: true

RailsApp::Application.routes.draw do
  devise_for :users
  devise_scope :user do
    resource :boolean_inviter_invitation, only: %i[new create]
    resource :free_invitation, only: %i[new create]
    resource :restricted_invitation, only: %i[new create]
    resource :admin, only: %i[new create]
  end
  devise_for :admins
  root to: 'home#index'
end
