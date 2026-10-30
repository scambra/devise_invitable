module DeviseInvitable
  class AmbiguousInviteKeyError < StandardError; end
  class InvitationDataTooLargeError < ArgumentError; end
  class MissingInviteKeyError < StandardError; end
  class ResourceAttributesRequirePlaceholderError < ArgumentError; end

  autoload :AcceptanceToken, 'devise_invitable/acceptance_token'
  autoload :Inviter, 'devise_invitable/inviter'
  autoload :Invitation, 'devise_invitable/invitation'
  autoload :InvitationDelivery, 'devise_invitable/invitation_delivery'
  autoload :InvitationDeliveryJob, 'devise_invitable/invitation_delivery_job'
  autoload :Mailer, 'devise_invitable/mailer'
  autoload :Migrator, 'devise_invitable/migrator'
  autoload :Mapping, 'devise_invitable/mapping'
  autoload :ParameterSanitizer, 'devise_invitable/parameter_sanitizer'
  module Controllers
    autoload :Registrations, 'devise_invitable/controllers/registrations'
    autoload :Helpers, 'devise_invitable/controllers/helpers'
  end

  def self.invitation_delivery_job
    job = Devise.invitation_delivery_job
    job = job.constantize if job.respond_to?(:constantize)
    return job if job.respond_to?(:perform_later)

    raise ArgumentError,
      'Devise.invitation_delivery_job must respond to perform_later'
  end
end

require 'devise'
require 'active_support/deprecation'
require 'devise_invitable/routes'
require 'devise_invitable/rails'

module Devise
  # Public: Validity period of the invitation token (default: 0). If
  # invite_for is 0 or nil, the invitation will never expire.
  # Set invite_for in the Devise configuration file (in config/initializers/devise.rb).
  #
  #   config.invite_for = 2.weeks # => The invitation token will be valid 2 weeks
  mattr_accessor :invite_for
  @@invite_for = 0

  # Public: Ensure that invited record is valid.
  # The invitation won't be sent if this check fails.
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
  #   config.invite_key = { email: /\A[^@]+@[^@]+\z/ }
  mattr_accessor :invite_key
  @@invite_key = { email: Devise.email_regexp }

  # Public: Resend invitation if user with invited status is invited again
  # (default: true)
  #
  # Example (in config/initializers/devise.rb)
  #
  #   config.resend_invitation = false
  mattr_accessor :resend_invitation
  @@resend_invitation = true

  # Deprecated compatibility setting. Invitations now always use a polymorphic
  # invited_by association.
  mattr_accessor :invited_by_class_name
  @@invited_by_class_name = nil

  def self.invited_by_class_name=(value)
    DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_class_name)
    @@invited_by_class_name = value
  end

  # Deprecated compatibility setting. The shared invitations table always uses
  # invited_by_id and invited_by_type.
  mattr_accessor :invited_by_foreign_key
  @@invited_by_foreign_key = nil

  def self.invited_by_foreign_key=(value)
    DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_foreign_key)
    @@invited_by_foreign_key = value
  end

  # Public: The column name used for counter_cache column. If this is nil,
  # the #invited_by association is declared without counter_cache. (default: nil)
  mattr_accessor :invited_by_counter_cache
  @@invited_by_counter_cache = nil

  # Public: Auto-login after the user accepts the invitation. If this is false,
  # the user will need to manually log in after accepting the invite (default: true).
  mattr_accessor :allow_insecure_sign_in_after_accept
  @@allow_insecure_sign_in_after_accept = true

  # Public: Require password when user accepts the invitation. Set to false if
  # you don't want to ask or enforce to set password while accepting, because is
  # set when user is invited or it will be set later (default: true).
  mattr_accessor :require_password_on_accepting
  @@require_password_on_accepting = true

  # Public: Create the invited resource as soon as an invitation is sent.
  # When false, only the invitation record is persisted and the resource is
  # created when the invitation is accepted.
  mattr_accessor :create_resource_on_invitation
  @@create_resource_on_invitation = false

  # Public: Store invite keys until an invitation is delivered so a skipped,
  # resource-less invitation can be delivered later. Stored keys are cleared
  # after successful delivery.
  mattr_accessor :store_invite_keys_until_delivery
  @@store_invite_keys_until_delivery = false

  # Public: Deliver invitation emails through the configured invitation job.
  # Other Devise notifications continue to use send_devise_notification.
  mattr_accessor :deliver_invitation_later
  @@deliver_invitation_later = false

  # Public: Active Job class used by Invitation#deliver_later. It may be a
  # class or a class name and must respond to perform_later.
  mattr_accessor :invitation_delivery_job
  @@invitation_delivery_job = 'DeviseInvitable::InvitationDeliveryJob'

  # Public: Queue used by the default invitation delivery job.
  mattr_accessor :invitation_delivery_queue_name
  @@invitation_delivery_queue_name = :mailers

  # Public: Supersede other pending invitations for the same invite keys when
  # one invitation is accepted. Disable this only when each invitation carries
  # an independently acceptable application-specific context.
  mattr_accessor :supersede_other_invitations_on_accept
  @@supersede_other_invitations_on_accept = true
end

module DeviseInvitable
  def self.deprecator
    @deprecator ||= ActiveSupport::Deprecation.new('3.0', 'DeviseInvitable')
  end

  def self.warn_deprecated_invited_by_setting(setting)
    deprecator.warn(
      "The #{setting} setting is deprecated and has no effect. " \
      "Invitations now always use a polymorphic invited_by association " \
      "with invited_by_id and invited_by_type."
    )
  end
end

Devise.add_module :invitable, controller: :invitations, model: 'devise_invitable/models', route: { invitation: [nil, :new, :accept] }
