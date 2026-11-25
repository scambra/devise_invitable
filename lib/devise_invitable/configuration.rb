# frozen_string_literal: true

# Adds global invitation settings to Devise.
module Devise
  # Public: Validity period of the invitation token (default: 0). If
  # invite_for is 0 or nil, the invitation will never expire.
  # Set invite_for in the Devise configuration file (in config/initializers/devise.rb).
  #
  #   config.invite_for = 2.weeks # => The invitation token will be valid 2 weeks
  mattr_accessor :invite_for, default: 0

  # Public: Ensure that invited record is valid.
  # The invitation won't be sent if this check fails.
  # (default: false).
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.validate_on_invite = true
  mattr_accessor :validate_on_invite, default: false

  # Public: number of invitations the user is allowed to send
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.invitation_limit = nil
  mattr_accessor :invitation_limit, default: nil

  # Public: The key to be used to check existing users when sending an invitation,
  # and the regexp used to test it when validate_on_invite is not set.
  #
  # Examples (in config/initializers/devise.rb)
  #
  #   config.invite_key = { email: /\A[^@]+@[^@]+\z/ }
  mattr_accessor :invite_key, default: { email: Devise.email_regexp }

  # Public: Resend invitation if user with invited status is invited again
  # (default: true)
  #
  # Example (in config/initializers/devise.rb)
  #
  #   config.resend_invitation = false
  mattr_accessor :resend_invitation, default: true

  # Deprecated compatibility setting. Invitations now always use a polymorphic
  # invited_by association.
  mattr_accessor :invited_by_class_name, default: nil

  # Deprecated compatibility setting. The shared invitations table always uses
  # invited_by_id and invited_by_type.
  mattr_accessor :invited_by_foreign_key, default: nil

  # Public: The column name used for counter_cache column. If this is nil,
  # the #invited_by association is declared without counter_cache. (default: nil)
  mattr_accessor :invited_by_counter_cache, default: nil

  # Public: Auto-login after the user accepts the invitation. If this is false,
  # the user will need to manually log in after accepting the invite (default: true).
  mattr_accessor :allow_insecure_sign_in_after_accept, default: true

  # Public: Require password when user accepts the invitation. Set to false if
  # you don't want to ask or enforce to set password while accepting, because is
  # set when user is invited or it will be set later (default: true).
  mattr_accessor :require_password_on_accepting, default: true

  # Public: Create the invited resource as soon as an invitation is sent.
  # When false, only the invitation record is persisted and the resource is
  # created when the invitation is accepted.
  mattr_accessor :create_resource_on_invitation, default: false

  # Public: Action applied to a resource's invitation records when the resource
  # is destroyed. Supported values are :nullify and :destroy.
  mattr_accessor :invitations_dependent, default: :nullify

  # Public: Store invite keys until an invitation is delivered so a skipped,
  # resource-less invitation can be delivered later. Stored keys are cleared
  # after successful delivery.
  mattr_accessor :store_invite_keys_until_delivery, default: false

  # Public: Accept and match invitation-key digests created before HMAC digests
  # were introduced. Disable only after verifying no pending invitation uses a
  # legacy unkeyed SHA-256 digest.
  mattr_accessor :allow_legacy_invite_key_digests, default: true

  # Public: Deliver invitation emails through the configured invitation job.
  # Other Devise notifications continue to use send_devise_notification.
  mattr_accessor :deliver_invitation_later, default: false

  # Public: Active Job class used by Invitation#deliver_later. It may be a
  # class or a class name and must respond to perform_later.
  mattr_accessor :invitation_delivery_job, default: 'DeviseInvitable::InvitationDeliveryJob'

  # Public: Queue used by the default invitation delivery job.
  mattr_accessor :invitation_delivery_queue_name, default: :mailers

  # Public: Supersede other pending invitations for the same invite keys when
  # one invitation is accepted. Disable this only when each invitation carries
  # an independently acceptable application-specific context.
  mattr_accessor :supersede_other_invitations_on_accept, default: true

  # Validates and warns on configuration writes while retaining mattr_accessor storage.
  module InvitableConfiguration
    def invited_by_class_name=(value)
      DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_class_name)
      super
    end

    def invited_by_foreign_key=(value)
      DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_foreign_key)
      super
    end

    def invitations_dependent=(value)
      unless DeviseInvitable::INVITATIONS_DEPENDENT_VALUES.include?(value)
        raise ArgumentError, 'invitations_dependent must be :nullify or :destroy'
      end

      super
    end
  end

  singleton_class.prepend InvitableConfiguration
end
