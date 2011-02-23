require 'devise'

require 'devise_invitable/mailer'
require 'devise_invitable/routes'
require 'devise_invitable/schema'
require 'devise_invitable/controllers/url_helpers'
require 'devise_invitable/controllers/helpers'
require 'devise_invitable/rails'

module Devise
  # The period the generated invitation token is valid.
  mattr_accessor :invite_for
  @@invite_for = 0

  # Public: number of invitations the user is allowed to send
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.invitation_limit = nil
  mattr_accessor :invitation_limit
  @@invitation_limit = nil
  
  # The key to be used to check existing users when sending an invitation
  mattr_accessor :invite_key
  @@invite_key = :email
end

Devise.add_module :invitable, :controller => :invitations, :model => 'devise_invitable/model', :route => :invitation
