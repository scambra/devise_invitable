module DeviseInvitable
  autoload :Inviter, 'devise_invitable/inviter'
  autoload :Mailer, 'devise_invitable/mailer'
  autoload :Mapping, 'devise_invitable/mapping'
  autoload :ParameterSanitizer, 'devise_invitable/parameter_sanitizer'
  module Controllers
    autoload :UrlHelpers, 'devise_invitable/controllers/url_helpers'
    autoload :Registrations, 'devise_invitable/controllers/registrations'
    autoload :Helpers, 'devise_invitable/controllers/helpers'
  end
end

require 'devise'
require 'devise_invitable/routes'
require 'devise_invitable/rails'

I18n.config.enforce_available_locales = true

module Devise
  # Public: Validity period of the invitation token (default: 0). If
  # invite_for is 0 or nil, the invitation will never expire.
  # Set invite_for in the Devise configuration file (in config/initializers/devise.rb).
  #
  #   config.invite_for = 2.weeks # => The invitation token will be valid 2 weeks
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

  # Public: number of invitations the user is allowed to send
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.invitation_limit = nil
  mattr_accessor :invitation_limit
  @@invitation_limit = nil

  # Public: The key to be used to check existing users when sending an invitation,
  # and the regexp used to test it when validate_on_invite is not set.
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.invite_key = {:email => /\A[^@]+@[^@]+\z/}
  mattr_accessor :invite_key
  @@invite_key = {:email => Devise.email_regexp}

  # Public: Resend invitation if user with invited status is invited again
  # (default: true)
  #
  # Example (in config/initializers/devise.rb)
  #
  #   config.resend_invitation = false
  mattr_accessor :resend_invitation
  @@resend_invitation = true

  # Public: The class name of the inviting model. If this is nil,
  # the #invited_by association is declared to be polymorphic. (default: nil)
  mattr_accessor :invited_by_class_name
  @@invited_by_class_name = nil
end

Devise.add_module :invitable, :controller => :invitations, :model => 'devise_invitable/model', :route => :invitation
