# frozen_string_literal: true

module Devise
  module Models
    module Invitable
      # Persists, delivers, accepts, and revokes a resource's invitations.
      module InvitationLifecycle
        # Marks the current invitation accepted without persisting the resource or
        # invitation. Use #accept_invitation! for the normal persisted workflow.
        def accept_invitation
          return unless current_invitation

          current_invitation.invitation_accepted_at = Time.now.utc
          current_invitation.invitation_token = nil
        end

        # Saves the resource and accepts +current_invitation+.
        #
        # By default, other pending invitations for the same invite keys are
        # superseded. Set +supersede_other_invitations_on_accept+ to +false+ when
        # each invitation must remain independently acceptable.
        def accept_invitation!
          return unless current_invitation&.pending?

          @accepted_invitation_for_provisioned_resource = resource_previously_provisioned?
          provisioning_acceptance = !accepted_invitation_for_provisioned_resource?
          previous_confirmed_at = confirmed_at if respond_to?(:confirmed_at)
          @accepting_invitation = true
          skip_reconfirmation! if respond_to?(:skip_reconfirmation!)
          saved =
            run_callbacks :invitation_accepted do
              persist_invitation_acceptance(provisioning_acceptance)
            end
          rollback_accepted_invitation(previous_confirmed_at) unless saved
          @accepting_invitation = false
          saved
        end

        # Restores invitation and confirmation state after a failed acceptance.
        def rollback_accepted_invitation(previous_confirmed_at = nil)
          invitation = current_invitation
          invitation.reload if invitation&.persisted?
          self.confirmed_at = previous_confirmed_at if respond_to?(:confirmed_at=)
        end

        # Creates and sends another invitation for this resource.
        #
        # This instance method does not perform the registered-account checks made
        # by the class-level +invite!+ method. Call it only from a trusted workflow
        # after verifying that the resource is eligible to be invited.
        #
        # Pass application-specific token data as
        # +options[:invitation_data]+. Set #skip_invitation to +true+ to create the
        # invitation without sending it.
        def invite!(invited_by = nil, options = {})
          options = options.dup
          invitation_data = options.delete(:invitation_data)
          resource_was_new = new_record?
          # Required to workaround confirmable model's confirmation_required? method
          # being implemented to check for non-nil value of confirmed_at
          if new_record_and_responds_to?(:confirmation_required?)
            define_singleton_method(:confirmation_required?) { false }
          end

          yield self if block_given?
          invitation = prepare_current_invitation(invited_by, invitation_data)

          run_callbacks :invitation_created do
            persist_and_deliver_invitation(invitation, options, resource_was_new)
          end
        end

        # Revokes the current pending invitation. A placeholder resource created
        # solely for that invitation is destroyed as part of the revocation.
        def revoke_invitation!
          invitation = current_invitation
          return unless invitation&.pending?

          remove_placeholder = invitation.provisioning?
          invitation.update!(revoked_at: Time.now.utc, invitation_token: nil)
          reset_devise_invitation_associations
          destroy if remove_placeholder
        end

        protected

        # Saves the resource before recording acceptance and resolving other invitations.
        def persist_invitation_acceptance(provisioning_acceptance)
          accepted_at = Time.now.utc
          self.confirmed_at ||= accepted_at if respond_to?(:confirmed_at=)
          return false unless save

          current_invitation.invitable = self
          current_invitation.resource_created_at ||= accepted_at if provisioning_acceptance
          current_invitation.invitation_accepted_at = accepted_at
          current_invitation.invitation_token = nil
          current_invitation.save!
          resolve_other_invitations_after_acceptance!(accepted_at)
          reset_devise_invitation_associations
          true
        end

        # Normalizes invite keys and prepares a new invitation and underlying token.
        def prepare_current_invitation(invited_by, invitation_data)
          downcase_keys if new_record_and_responds_to?(:downcase_keys)
          strip_whitespace if new_record_and_responds_to?(:strip_whitespace)
          invitation = build_devise_invitation(invited_by)
          invitation.invitation_data = invitation_data
          if instance_variable_defined?(:@invited_by_for_next_invitation)
            remove_instance_variable(:@invited_by_for_next_invitation)
          end
          @current_invitation = invitation
          generate_invitation_token
          invitation
        end

        # Persists an invitation, optionally provisioning its resource, before delivery.
        def persist_and_deliver_invitation(invitation, options, resource_was_new)
          invitation.invitation_data = DeviseInvitable::AcceptanceToken
                                         .normalize_invitation_data(invitation.invitation_data)
          now = Time.now.utc
          invitation.invitation_created_at = now

          validate = options.key?(:validate) ? options[:validate] : self.class.validate_on_invite
          return if self.class.create_resource_on_invitation && !save(validate: validate)

          if self.class.create_resource_on_invitation
            invitation.invitable = self
            invitation.resource_created_at = now if resource_was_new
          end
          invitation.save!
          reset_devise_invitation_associations
          generate_acceptance_token
          invitation.invited_by.decrement_invitation_limit! if invitation.invited_by.present?
          deliver_or_enqueue_invitation(options) unless skip_invitation
        end

        # Dispatches invitation delivery according to the resource's configuration.
        def deliver_or_enqueue_invitation(options)
          if self.class.deliver_invitation_later
            enqueue_invitation_delivery(options)
          else
            deliver_invitation(options)
          end
        end

        # Deletes invitation records before the association's default
        # nullification callback when the model opts into dependent destruction.
        def destroy_devise_invitations_if_configured
          devise_invitations.destroy_all if self.class.invitations_dependent == :destroy
        end

        # Returns whether an Active Record or Mongoid association is loaded.
        def devise_invitable_association_loaded?(association)
          return association.loaded? if association.respond_to?(:loaded?)

          association._loaded?
        end

        # Enqueues delivery of #current_invitation with its generated acceptance
        # token and mailer +options+.
        def enqueue_invitation_delivery(options)
          DeviseInvitable::InvitationDelivery.enqueue(
            current_invitation,
            resource: self,
            acceptance_token: acceptance_token,
            options: options
          )
        end

        # Updates an attribute on #current_invitation and saves it when the
        # invitation has already been persisted.
        def assign_invitation_attribute(attribute, value)
          return unless current_invitation

          current_invitation.public_send("#{attribute}=", value)
          return unless current_invitation.persisted?

          current_invitation.save!
          reset_devise_invitation_associations
        end

        # Returns whether invitation state should block authentication.
        def block_from_invitation?
          invitation_pending?
        end

        # Clears the resource's cached invitation associations.
        def reset_devise_invitation_associations
          devise_invitations.reset
          pending_invitations.reset
        end

        # Checks if the invitation for the user is within the limit time.
        # We do this by calculating if the difference between today and the
        # invitation sent date does not exceed the invite for time configured.
        # Invite_for is a model configuration, must always be an integer value.
        #
        # Example:
        #
        #   # invite_for = 1.day and invitation_sent_at = today
        #   invitation_period_valid?   # returns true
        #
        #   # invite_for = 5.days and invitation_sent_at = 4.days.ago
        #   invitation_period_valid?   # returns true
        #
        #   # invite_for = 5.days and invitation_sent_at = 5.days.ago
        #   invitation_period_valid?   # returns false
        #
        #   # invite_for = nil
        #   invitation_period_valid?   # will always return true
        #
        def invitation_period_valid?
          current_invitation&.invitation_period_valid?(self.class.invite_for)
        end

        # Generates a new random token for invitation, and stores the time
        # this token is being generated
        def generate_invitation_token
          # Tokens live in the invitations store, so check uniqueness there
          # instead of on the resource, which may no longer have the column
          raw, enc = Devise.token_generator.generate(DeviseInvitable::Invitation, :invitation_token)
          @raw_invitation_token = raw
          current_invitation.invitation_token = enc
        end

        # Generates and persists a new underlying Devise invitation token.
        def generate_invitation_token!
          generate_invitation_token && current_invitation.save!
        end

        # Builds the encrypted acceptance envelope for #current_invitation.
        def generate_acceptance_token
          @acceptance_token = DeviseInvitable::AcceptanceToken.generate(
            invitation: current_invitation,
            raw_token: @raw_invitation_token,
            invite_key: current_invitation.invite_key_for_acceptance.presence ||
              self.class.normalized_invite_keys(attributes),
            invitation_data: current_invitation.invitation_data
          )
        end

        # Ensures the current invitation has fresh underlying and acceptance
        # tokens, then returns the acceptance token.
        def prepare_invitation_delivery
          generate_invitation_token! unless @raw_invitation_token
          generate_acceptance_token unless acceptance_token
          acceptance_token
        end

        # Sends invitation instructions immediately through the configured
        # Devise mailer. This is used from within the delivery job.
        def send_invitation_notification_now(token, options)
          devise_mailer
            .send(:invitation_instructions, self, token, options)
            .deliver_now
        end

        # Returns whether this is a new resource that responds to +method+.
        def new_record_and_responds_to?(method)
          new_record? && respond_to?(method, true)
        end

        # Builds an unpersisted invitation with normalized invite keys and its
        # polymorphic inviter.
        def build_devise_invitation(invited_by)
          invite_key_values = self.class.normalized_invite_keys(attributes)
          invitation = DeviseInvitable::Invitation.new(
            invitable_type: self.class.devise_invitable_base_class.name,
            invite_key: {},
            invited_by: invited_by || invited_by_for_next_invitation
          )
          invitation.transient_invite_key = invite_key_values
          invitation
        end

        # Supersedes or preserves other matching invitations according to the
        # +supersede_other_invitations_on_accept+ setting.
        def resolve_other_invitations_after_acceptance!(time)
          if self.class.supersede_other_invitations_on_accept
            supersede_other_invitations!(time)
          else
            preserve_other_invitations!
          end
        end

        # Marks other pending invitations for the same invite keys superseded.
        def supersede_other_invitations!(time)
          invitations = self.class.pending_invitations_for(attributes)
          invitations.each do |invitation|
            next if invitation.id == current_invitation.id

            invitation.update!(
              invitable: self,
              invitation_token: nil,
              superseded_at: time,
              superseded_reason: 'accepted_other_invitation'
            )
          end
        end

        # Associates other matching invitations with this resource while
        # leaving them independently acceptable.
        def preserve_other_invitations!
          self.class.pending_invitations_for(attributes).each do |invitation|
            next if invitation.id == current_invitation.id

            invitation.invitable = self
            invitation.resource_created_at = nil if current_invitation.provisioning?
            invitation.save!
          end
        end

        # Supersedes matching pending invitations after direct registration.
        def resolve_invitations_after_registration!
          self.class.pending_invitations_for(attributes).each do |invitation|
            invitation.update!(
              invitable: self,
              invitation_token: nil,
              superseded_at: Time.now.utc,
              superseded_reason: 'registered'
            )
          end
          reset_devise_invitation_associations
          self.registering_directly = false
        end
      end
    end
  end
end
