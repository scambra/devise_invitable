require 'devise'

require 'devise_invitable/mailer'
require 'devise_invitable/rails'
require 'devise_invitable/routes'
require 'devise_invitable/schema'
require 'devise_invitable/controllers/internal_helpers'

module Devise
  # Public: Time interval where the invitation token is valid (default: 0). If 
  # invite_for is 0 or nil, the invitation will never expire. Set invite_for in 
  # the Devise configuration file.
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.invite_for = 2.weeks
  mattr_accessor :invite_for
  @@invite_for = 0
  
  # Public: Flag that force a record to be valid before being actually invited 
  # (default: false).
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.validate_on_invite = true
  mattr_accessor :validate_on_invite
  @@validate_on_invite = false
end

Devise.add_module(:invitable,
  :controller => :invitations,
  :model => 'devise_invitable/model',
  :route => :invitation)