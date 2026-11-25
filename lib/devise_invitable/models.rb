# frozen_string_literal: true

require 'active_support/deprecation'
require 'devise_invitable/models/authenticatable'
require 'devise_invitable/models/invitable/class_methods'
require 'devise_invitable/models/invitable/invitation_lifecycle'

module Devise
  module Models
    # Invitable is responsible for sending invitation emails.
    # Invitations are stored separately. An account is created immediately only
    # when create_resource_on_invitation is enabled; otherwise it is created on
    # acceptance.
    # Invitation email contains a link allowing the user to accept the invitation
    # by setting a password (as reset password from Devise's recoverable module).
    #
    # Configuration:
    #
    #   invite_for: The period the generated invitation token is valid.
    #               After this period, the invited resource won't be able to accept the invitation.
    #               When invite_for is 0 (the default), the invitation won't expire.
    #
    # Examples:
    #
    #   User.find(1).invited_to_sign_up?                    # => true/false
    #   User.invite!(email: 'someone@example.com')          # => send invitation
    #   User.accept_invitation!(invitation_token: '...')    # => accept invitation with a token
    #   User.find(1).accept_invitation!                     # => accept invitation
    #   User.find(1).invite!                                # => reset invitation status and send invitation again
    module Invitable
      extend ActiveSupport::Concern
      include InvitationLifecycle

      # When +true+, creates the invitation without sending its email.
      attr_accessor :skip_invitation

      # Internal compatibility flag used while completing an invitation.
      attr_accessor :completing_invite

      # Marks a direct registration so matching invitations can be superseded
      # after the resource is saved.
      attr_accessor :registering_directly

      # Temporarily stores the inviter while a new invitation is being built.
      attr_accessor :invited_by_for_next_invitation

      # The encrypted token generated for the invitation being created.
      attr_reader   :acceptance_token

      included do
        include ::DeviseInvitable::Inviter

        has_many :devise_invitations,
                 as: :invitable,
                 class_name: 'DeviseInvitable::Invitation',
                 dependent: :nullify,
                 autosave: true
        before_destroy :destroy_devise_invitations_if_configured, prepend: true
        if defined?(Mongoid::Document) && self < Mongoid::Document
          has_many :pending_invitations,
                   as: :invitable,
                   class_name: 'DeviseInvitable::Invitation',
                   foreign_key: :invitable_id,
                   inverse_of: false,
                   scope: -> { pending.provisioning }
        else
          has_many :pending_invitations,
                   -> { pending.provisioning },
                   as: :invitable,
                   class_name: 'DeviseInvitable::Invitation',
                   foreign_key: :invitable_id,
                   inverse_of: false
        end
        extend ActiveModel::Callbacks

        define_model_callbacks :invitation_created
        define_model_callbacks :invitation_accepted
        after_save :resolve_invitations_after_registration!, if: :registering_directly

        if defined?(Mongoid::Document) && self < Mongoid::Document
          scope :created_by_invite, lambda {
            ids = DeviseInvitable::Invitation.provisioning
                                             .where(invitable_type: devise_invitable_base_class.name)
                                             .pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :invitation_not_accepted, lambda {
            ids = DeviseInvitable::Invitation.pending.provisioning
                                             .where(invitable_type: devise_invitable_base_class.name)
                                             .pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :invitation_accepted, lambda {
            ids = DeviseInvitable::Invitation.accepted
                                             .where(invitable_type: devise_invitable_base_class.name)
                                             .pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :no_active_invitation, lambda {
            ids = DeviseInvitable::Invitation.pending.where(invitable_type: devise_invitable_base_class.name)
                                             .where(:invitable_id.ne => nil).pluck(:invitable_id)
            where(:id.nin => ids)
          }
        elsif defined?(ActiveRecord::Base) && self < ActiveRecord::Base
          scope :created_by_invite, lambda {
            invitation_ids = DeviseInvitable::Invitation.provisioning
                                                        .where(invitable_type: devise_invitable_base_class.name)
                                                        .select(:invitable_id)
            where(id: invitation_ids)
          }
          scope :invitation_not_accepted, lambda {
            invitation_ids = DeviseInvitable::Invitation.pending.provisioning
                                                        .where(invitable_type: devise_invitable_base_class.name)
                                                        .select(:invitable_id)
            where(id: invitation_ids)
          }
          scope :invitation_accepted, lambda {
            invitation_ids = DeviseInvitable::Invitation.accepted
                                                        .where(invitable_type: devise_invitable_base_class.name)
                                                        .select(:invitable_id)
            where(id: invitation_ids)
          }
          scope :no_active_invitation, lambda {
            invitation_ids = DeviseInvitable::Invitation.pending
                                                        .where(invitable_type: devise_invitable_base_class.name)
                                                        .where.not(invitable_id: nil)
                                                        .select(:invitable_id)
            where.not(id: invitation_ids)
          }

          callbacks = %i[
            before_invitation_created
            after_invitation_created
            before_invitation_accepted
            after_invitation_accepted
          ]

          callbacks.each do |callback_method|
            send callback_method
          end
        end
      end

      # Declares that Invitable does not require legacy columns on the resource.
      def self.required_fields(_klass)
        []
      end

      # Returns the pending invitation selected for this resource, or its most
      # recently created invitation when none are pending.
      #
      # Invitation callbacks can use this method to inspect the invitation being
      # created or accepted, including its transient +invitation_data+.
      def current_invitation
        @current_invitation ||=
          if persisted?
            devise_invitations.pending.order(invitation_created_at: :desc).first ||
              devise_invitations.order(invitation_created_at: :desc).first
          end
      end

      # Reloads the resource and clears the cached #current_invitation.
      def reload(*args)
        @current_invitation = nil
        super
      end

      # Returns the encrypted Devise token stored on #current_invitation.
      # Use #raw_invitation_token when constructing an acceptance URL.
      def invitation_token
        current_invitation&.invitation_token
      end

      # Assigns the encrypted Devise token on #current_invitation.
      def invitation_token=(value)
        current_invitation&.invitation_token = value
      end

      # Returns the token that must be passed to an invitation acceptance URL.
      #
      # For new invitations this is an encrypted, authenticated envelope. It is
      # available only on the object that created the invitation and is not
      # persisted in plaintext.
      def raw_invitation_token
        acceptance_token || @raw_invitation_token
      end

      # Returns when the current invitation was created.
      def invitation_created_at
        current_invitation&.invitation_created_at
      end

      # Sets when the current invitation was created, persisting an existing
      # invitation immediately.
      def invitation_created_at=(value)
        assign_invitation_attribute(:invitation_created_at, value)
      end

      # Returns when the current invitation email was sent.
      def invitation_sent_at
        current_invitation&.invitation_sent_at
      end

      # Sets when the current invitation email was sent, persisting an existing
      # invitation immediately.
      def invitation_sent_at=(value)
        assign_invitation_attribute(:invitation_sent_at, value)
      end

      # Returns when the current invitation was accepted.
      def invitation_accepted_at
        current_invitation&.invitation_accepted_at
      end

      # Sets when the current invitation was accepted, persisting an existing
      # invitation immediately.
      def invitation_accepted_at=(value)
        assign_invitation_attribute(:invitation_accepted_at, value)
      end

      # Returns the inviter for the current invitation, or the inviter staged
      # for the invitation currently being built.
      def invited_by
        if instance_variable_defined?(:@invited_by_for_next_invitation)
          invited_by_for_next_invitation
        else
          current_invitation&.invited_by
        end
      end

      # Assigns the inviter to the current invitation, or stages it for the next
      # invitation when no current invitation exists.
      def invited_by=(value)
        if current_invitation
          current_invitation.invited_by = value
        else
          self.invited_by_for_next_invitation = value
        end
      end

      # Returns the polymorphic identifier of the current invitation's inviter.
      def invited_by_id
        current_invitation&.invited_by_id
      end

      # Returns the polymorphic type of the current invitation's inviter.
      def invited_by_type
        current_invitation&.invited_by_type
      end

      # Returns whether this resource was created through the invitation
      # workflow, irrespective of the invitation's current state.
      def created_by_invite?
        devise_invitations.provisioning.exists?
      end

      # Returns whether the resource existed before the current invitation was
      # accepted, rather than being provisioned by that invitation.
      def resource_previously_provisioned?
        persisted? && !invitation_pending?
      end

      # Returns whether the invitation currently being accepted belongs to an
      # already provisioned resource.
      def accepted_invitation_for_provisioned_resource?
        !!@accepted_invitation_for_provisioned_resource
      end

      # Returns +true+ only while this resource is a placeholder created by an
      # unresolved invitation. An active resource may have other pending
      # invitations without itself being pending.
      def invitation_pending?
        return false unless persisted?

        invitations = pending_invitations
        if devise_invitable_association_loaded?(invitations)
          return invitations.any?
        end

        invitations.exists?
      end

      # Returns whether this resource is currently accepting an invitation or is
      # a pending placeholder awaiting acceptance.
      def invited_to_sign_up?
        accepting_invitation? || invitation_pending?
      end

      # Returns +true+ while #accept_invitation! is running.
      def accepting_invitation?
        instance_variable_defined?(:@accepting_invitation) && @accepting_invitation
      end

      # Returns whether this resource has an accepted invitation. This is +false+
      # while an invitation is being accepted.
      def invitation_accepted?
        !accepting_invitation? && devise_invitations.accepted.exists?
      end

      # Returns whether this resource has accepted an invitation or was never a
      # pending invitee.
      def accepted_or_not_invited?
        invitation_accepted? || !invited_to_sign_up?
      end

      # Returns whether the current invitation is pending and has not expired.
      # Invitation validity starts at +invitation_sent_at+.
      def valid_invitation?
        current_invitation&.pending? && invitation_period_valid?
      end

      # Delegates password verification to Devise unless a pending invitation
      # blocks authentication.
      def valid_password?(password)
        super unless !accepting_invitation? && block_from_invitation?
      end

      # Prevents a pending placeholder resource from authenticating.
      def active_for_authentication?
        super && !block_from_invitation?
      end

      # Returns +:invited+ for a pending placeholder; otherwise delegates to
      # Devise for the normal inactive reason.
      def inactive_message
        block_from_invitation? ? :invited : super
      end

      # Prevents the password-changed notification while accepting an invitation.
      def send_password_change_notification?
        super && !accepting_invitation?
      end

      # Requires a password for a newly provisioned invitee when configured to
      # do so, while preserving Devise's other password requirements.
      def password_required?
        (accepting_invitation? && !resource_previously_provisioned? &&
          self.class.require_password_on_accepting) || super
      end

      # Returns +:invited+ for a pending placeholder; otherwise delegates to
      # Devise for the normal unauthenticated reason.
      def unauthenticated_message
        block_from_invitation? ? :invited : super
      end

      # Clears a Devise reset-password token and accepts a valid invitation when
      # the reset was also serving as invitation acceptance.
      def clear_reset_password_token
        reset_password_token_present = reset_password_token.present?
        super
        accept_invitation! if reset_password_token_present && valid_invitation?
      end

      # Removes validation errors for invite keys that match their configured
      # validation expressions.
      def clear_errors_on_valid_keys
        self.class.invite_key.each do |key, value|
          case send(key)
          when value
            errors.delete(key)
          end
        end
      end

      # Delivers the current invitation email synchronously.
      #
      # Usually applications call DeviseInvitable::Invitation#deliver when
      # sending a previously skipped invitation.
      def deliver_invitation(options = {})
        DeviseInvitable::InvitationDelivery.call(
          current_invitation,
          resource: self,
          acceptance_token: acceptance_token,
          options: options
        )
      end

      # Returns the encrypted invitation token stored by Devise.
      # This is an explicit alias for #invitation_token.
      def encrypted_invitation_token
        invitation_token
      end

      # Returns whether the resource requires Devise confirmation while it is
      # completing an invitation.
      def confirmation_required_for_invited?
        respond_to?(:confirmation_required?, true) && confirmation_required?
      end

      # Returns the time at which the current invitation expires, or +nil+ when
      # it has not been sent or invitations do not expire.
      def invitation_due_at
        return nil if self.class.invite_for.nil? || self.class.invite_for.zero?

        return unless (time = invitation_sent_at)

        time + self.class.invite_for
      end

      # Adds a +:taken+ validation error for the invite-key +key+.
      def add_taken_error(key)
        errors.add(key, :taken)
      end

      # Returns whether this persisted resource is not a pending placeholder and
      # therefore cannot be claimed by a new invitation.
      def invitation_taken?
        persisted? && !invitation_pending?
      end
    end
  end
end
