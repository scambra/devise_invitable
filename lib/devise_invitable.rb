require 'devise'

require 'devise_invitable/mailer'
require 'devise_invitable/rails'
require 'devise_invitable/routes'
require 'devise_invitable/schema'
require 'devise_invitable/controllers/url_helpers'

module Devise
  # Time interval where the invitation token is valid.
  mattr_accessor :invite_for
  @@invite_for = 0
  
  # Whether you want to validate the record on a new invite
  mattr_accessor :validate_on_invite
  @@validate_on_invite = false
end

Devise.add_module(:invitable,
  :controller => :invitations,
  :model => 'devise_invitable/model',
  :route => :invitation)