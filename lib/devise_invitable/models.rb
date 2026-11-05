require 'active_support/deprecation'
require 'devise_invitable/models/authenticatable'

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
              .where(invitable_type: devise_invitable_base_class.name).pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :invitation_not_accepted, lambda {
            ids = DeviseInvitable::Invitation.pending.provisioning
              .where(invitable_type: devise_invitable_base_class.name).pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :invitation_accepted, lambda {
            ids = DeviseInvitable::Invitation.accepted
              .where(invitable_type: devise_invitable_base_class.name).pluck(:invitable_id)
            where(:id.in => ids)
          }
          scope :no_active_invitation, lambda {
            ids = DeviseInvitable::Invitation.pending.where(invitable_type: devise_invitable_base_class.name)
              .where(:invitable_id.ne => nil).pluck(:invitable_id)
            where(:id.nin => ids)
          }
        elsif defined?(ActiveRecord) && defined?(ActiveRecord::Base) && self < ActiveRecord::Base
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

          callbacks = [
            :before_invitation_created,
            :after_invitation_created,
            :before_invitation_accepted,
            :after_invitation_accepted,
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
        if current_invitation&.pending?
          @accepted_invitation_for_provisioned_resource = resource_previously_provisioned?
          provisioning_acceptance = !accepted_invitation_for_provisioned_resource?
          previous_confirmed_at = confirmed_at if respond_to?(:confirmed_at)
          @accepting_invitation = true
          skip_reconfirmation! if respond_to?(:skip_reconfirmation!)
          run_callbacks :invitation_accepted do
            accepted_at = Time.now.utc
            self.confirmed_at ||= accepted_at if respond_to?(:confirmed_at=)

            if save
              current_invitation.invitable = self
              current_invitation.resource_created_at ||= accepted_at if provisioning_acceptance
              current_invitation.invitation_accepted_at = accepted_at
              current_invitation.invitation_token = nil
              current_invitation.save!
              resolve_other_invitations_after_acceptance!(accepted_at)
              reset_devise_invitation_associations
              true
            else
              false
            end
          end.tap do |saved|
            rollback_accepted_invitation(previous_confirmed_at) unless saved
            @accepting_invitation = false
          end
        end
      end

      # Restores invitation and confirmation state after a failed acceptance.
      def rollback_accepted_invitation(previous_confirmed_at = nil)
        invitation = current_invitation
        invitation.reload if invitation&.persisted?
        self.confirmed_at = previous_confirmed_at if respond_to?(:confirmed_at=)
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
          def self.confirmation_required?; false; end
        end

        yield self if block_given?
        # Normalize invite keys before they are copied to the invitation.
        self.downcase_keys if new_record_and_responds_to?(:downcase_keys)
        self.strip_whitespace if new_record_and_responds_to?(:strip_whitespace)
        invitation = build_devise_invitation(invited_by)
        invitation.invitation_data = invitation_data
        if instance_variable_defined?(:@invited_by_for_next_invitation)
          remove_instance_variable(:@invited_by_for_next_invitation)
        end
        @current_invitation = invitation
        generate_invitation_token

        run_callbacks :invitation_created do
          invitation.invitation_data = DeviseInvitable::AcceptanceToken
            .normalize_invitation_data(invitation.invitation_data)
          now = Time.now.utc
          invitation.invitation_created_at = now

          validate = options.key?(:validate) ? options[:validate] : self.class.validate_on_invite
          save_invitation = !self.class.create_resource_on_invitation || save(validate: validate)
          if save_invitation
            if self.class.create_resource_on_invitation
              invitation.invitable = self
              invitation.resource_created_at = now if resource_was_new
            end
            invitation.save!
            reset_devise_invitation_associations
            generate_acceptance_token
            invitation.invited_by.decrement_invitation_limit! if invitation.invited_by.present?
            unless skip_invitation
              if self.class.deliver_invitation_later
                enqueue_invitation_delivery(options)
              else
                deliver_invitation(options)
              end
            end
          end
        end
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
          self.errors.delete(key) if value === self.send(key)
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
        self.invitation_token
      end

      # Returns whether the resource requires Devise confirmation while it is
      # completing an invitation.
      def confirmation_required_for_invited?
        respond_to?(:confirmation_required?, true) && confirmation_required?
      end

      # Returns the time at which the current invitation expires, or +nil+ when
      # it has not been sent or invitations do not expire.
      def invitation_due_at
        return nil if (self.class.invite_for == 0 || self.class.invite_for.nil?)

        return unless (time = self.invitation_sent_at)

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
          if current_invitation.persisted?
            current_invitation.save!
            reset_devise_invitation_associations
          end
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
          self.new_record? && self.respond_to?(method, true)
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

      module ClassMethods
        # Returns the root persistence class used as the invitation's
        # polymorphic +invitable_type+.
        def devise_invitable_base_class
          if respond_to?(:base_class)
            base_class
          elsif respond_to?(:root_class)
            root_class
          else
            self
          end
        end

        # Returns the configured invite-key field names.
        def invite_key_fields
          invite_key.keys
        end

        # Internal implementation shared by .invite! and .invite_mail!.
        def _invite(attributes = {}, invited_by = nil, options = {}, &block)
          invite_key_array = invite_key_fields
          skip_invitation = attributes.delete(:skip_invitation)
          attributes_hash = {}
          invite_key_array.each do |k|
            attribute = attributes.delete(k)
            attribute = attribute.to_s.strip if strip_whitespace_keys.include?(k)
            attributes_hash[k] = attribute
          end

          ensure_unique_invite_key_match!(invite_key_array, attributes_hash)
          invitable = find_or_initialize_with_errors(invite_key_array, attributes_hash)
          invitable.assign_attributes(attributes_hash)
          # Association writers may persist changes immediately. Reject an
          # existing resource before assigning non-key attributes or yielding.
          if invitable.persisted? && (invitable.invitation_taken? || !self.resend_invitation)
            invite_key_array.each do |key|
              invitable.add_taken_error(key)
            end
            return [invitable, nil]
          end

          invitable.assign_attributes(attributes)
          invitable.skip_invitation = skip_invitation unless skip_invitation.nil?
          invitable.invited_by_for_next_invitation = invited_by
          if create_resource_on_invitation && !(invitable.password || invitable.encrypted_password.present?)
            invitable.password = random_password
          end

          invitable.valid? if self.validate_on_invite && create_resource_on_invitation
          if !create_resource_on_invitation && !resend_invitation && pending_invitations_for(attributes_hash).any?
            invite_key_array.each { |key| invitable.add_taken_error(key) }
          elsif invitable.new_record?
            invitable.clear_errors_on_valid_keys if !self.validate_on_invite
          end

          resource_attribute_names = attributes.keys.map(&:to_sym)
          changes_before_block = invitable.changes.dup
          yield invitable if block_given?
          unless create_resource_on_invitation
            block_attribute_names = invitable.changes.each_with_object([]) do |(attribute, change), names|
              names << attribute.to_sym unless changes_before_block[attribute] == change
            end
            changed_resource_attributes =
              (resource_attribute_names + block_attribute_names).uniq - invite_key_array.map(&:to_sym)
            if changed_resource_attributes.any?
              raise DeviseInvitable::ResourceAttributesRequirePlaceholderError,
                "Cannot assign resource attributes (#{changed_resource_attributes.join(', ')}) when " \
                'create_resource_on_invitation is disabled'
            end
          end
          mail = invitable.invite!(invited_by, options.merge(validate: false)) if invitable.errors.empty?
          [invitable, mail]
        end

        # Creates an invitation and returns the invited resource.
        #
        # +attributes+ must include every configured invite key. By default only
        # a DeviseInvitable::Invitation is persisted; enable
        # +create_resource_on_invitation+ to create a placeholder resource and
        # persist additional resource attributes immediately.
        #
        # The optional +invited_by+ resource is stored on the invitation.
        # +options[:invitation_data]+ may contain a small JSON-compatible hash to
        # carry in the encrypted acceptance token. Set +:skip_invitation+ in
        # +attributes+ (or set #skip_invitation in the block) to store the
        # invitation without sending its email.
        def invite!(attributes = {}, invited_by = nil, options = {}, &block)
          attr_hash = ActiveSupport::HashWithIndifferentAccess.new(attributes.to_h)
          _invite(attr_hash, invited_by, options, &block).first
        end

        # Creates an invitation like .invite!, but returns the mail delivery
        # result instead of the invited resource.
        def invite_mail!(attributes = {}, invited_by = nil, options = {}, &block)
          _invite(attributes, invited_by, options, &block).last
        end

        # Accepts an invitation and returns the invited resource.
        #
        # +attributes+ must include +:invitation_token+ and may include the
        # password, password confirmation, and other permitted resource
        # attributes. An invalid token returns a new resource with an error on
        # +invitation_token+.
        def accept_invitation!(attributes = {})
          original_token = attributes.delete(:invitation_token)
          invitable = find_by_invitation_token(original_token, false)
          if invitable.errors.empty?
            if invitable.resource_previously_provisioned?
              attributes.delete(:password)
              attributes.delete(:password_confirmation)
            end
            invitable.assign_attributes(attributes)
            invitable.accept_invitation!
          end
          invitable
        end

        # Finds the resource identified by +original_token+.
        #
        # When +only_valid+ is +true+, returns +nil+ for a blank, invalid, or
        # expired token. Otherwise returns a resource with an error on
        # +invitation_token+ when the token cannot be accepted.
        def find_by_invitation_token(original_token, only_valid)
          if original_token.blank?
            invitable = new
            invitable.errors.add(:invitation_token, :blank)
            return invitable unless only_valid
            return
          end

          invitation, invite_key = invitation_and_key_from_token(original_token)
          invitable = invitation&.invitable || new(invite_key || {})
          invitable.assign_attributes(invite_key) if invitation && invite_key.present?
          invitable.instance_variable_set(:@current_invitation, invitation)
          if invitation.nil?
            invitable.errors.add(:invitation_token, :invalid)
          elsif !invitable.valid_invitation?
            invitable.errors.add(:invitation_token, :invalid)
          end
          invitable unless only_valid && invitable.errors.present?
        end

        # Returns pending invitations whose normalized invite keys match
        # +attributes+.
        def pending_invitations_for(attributes)
          keys = normalized_invite_keys(attributes)
          resource_type = devise_invitable_base_class.name
          digest_candidates =
            DeviseInvitable::Invitation.digest_candidates_for(
              resource_type,
              keys,
              allow_legacy: allow_legacy_invite_key_digests
            )
          invitations =
            digest_candidates.flat_map do |digest|
              DeviseInvitable::Invitation.to_adapter.find_all(
                conditions: {
                  invitation_accepted_at: nil,
                  superseded_at: nil,
                  revoked_at: nil,
                  invitable_type: resource_type,
                  invite_key_digest: digest
                }
              ).to_a
            end
          invitations.uniq { |invitation| invitation.id.to_s }
        end

        # Extracts and normalizes configured invite keys from +attributes+ using
        # the model's whitespace and case-insensitivity settings.
        def normalized_invite_keys(attributes)
          attributes.to_h.with_indifferent_access.slice(*invite_key_fields).each_with_object({}) do |(key, value), keys|
            value = value.to_s.strip if strip_whitespace_keys.include?(key.to_sym)
            value = value.downcase if value.respond_to?(:downcase) && case_insensitive_keys.include?(key.to_sym)
            keys[key] = value
          end
        end

        # Registers a callback to run before an invitation is created.
        def before_invitation_created(*args, &blk)
          set_callback(:invitation_created, :before, *args, &blk)
        end

        # Registers a callback to run after an invitation is created.
        def after_invitation_created(*args, &blk)
          set_callback(:invitation_created, :after, *args, &blk)
        end

        # Registers a callback to run before an invitation is accepted.
        def before_invitation_accepted(*args, &blk)
          set_callback(:invitation_accepted, :before, *args, &blk)
        end

        # Registers a callback to run after an invitation is accepted.
        def after_invitation_accepted(*args, &blk)
          set_callback(:invitation_accepted, :after, *args, &blk)
        end


        Devise::Models.config(self, :invite_for)
        Devise::Models.config(self, :validate_on_invite)
        Devise::Models.config(self, :invitation_limit)
        Devise::Models.config(self, :invite_key)
        Devise::Models.config(self, :resend_invitation)
        Devise::Models.config(self, :invited_by_class_name)
        Devise::Models.config(self, :invited_by_foreign_key)
        Devise::Models.config(self, :invited_by_counter_cache)
        Devise::Models.config(self, :allow_insecure_sign_in_after_accept)
        Devise::Models.config(self, :require_password_on_accepting)
        Devise::Models.config(self, :create_resource_on_invitation)
        Devise::Models.config(self, :store_invite_keys_until_delivery)
        Devise::Models.config(self, :allow_legacy_invite_key_digests)
        Devise::Models.config(self, :deliver_invitation_later)
        Devise::Models.config(self, :supersede_other_invitations_on_accept)

        # Sets the deprecated +invited_by_class_name+ compatibility option.
        # Invitations always use a polymorphic inviter association.
        def invited_by_class_name=(value)
          DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_class_name)
          @invited_by_class_name = value
        end

        # Sets the deprecated +invited_by_foreign_key+ compatibility option.
        # Invitations always use +invited_by_id+ and +invited_by_type+.
        def invited_by_foreign_key=(value)
          DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_foreign_key)
          @invited_by_foreign_key = value
        end

        private

          def invitation_and_key_from_token(original_token)
            payload = DeviseInvitable::AcceptanceToken.decode(original_token)
            return legacy_invitation_and_key(original_token) unless payload
            return [nil, nil] unless payload[:invitable_type] == devise_invitable_base_class.name

            invitation_token = Devise.token_generator.digest(
              self,
              :invitation_token,
              payload[:raw_token]
            )
            invitation = DeviseInvitable::Invitation.to_adapter.find_first(
              id: payload[:invitation_id],
              invitable_type: devise_invitable_base_class.name,
              invitation_token: invitation_token
            )
            invitation.invitation_data = payload[:invitation_data] || {} if invitation
            invite_key = normalized_invite_keys(payload[:invite_key] || {})
            invitation = nil unless invitation &&
              DeviseInvitable::Invitation.valid_digest?(
                invitation.invite_key_digest,
                devise_invitable_base_class.name,
                invite_key,
                allow_legacy: allow_legacy_invite_key_digests
              )
            [invitation, invite_key]
          end

          def legacy_invitation_and_key(original_token)
            invitation_token = Devise.token_generator.digest(self, :invitation_token, original_token)
            invitation = DeviseInvitable::Invitation.to_adapter.find_first(
              invitable_type: devise_invitable_base_class.name,
              invitation_token: invitation_token
            )
            [invitation, invitation&.invite_key]
          end

          def ensure_unique_invite_key_match!(required_attributes, attributes)
            filtered_attributes = attributes.to_h.with_indifferent_access
              .slice(*required_attributes)
              .delete_if { |_key, value| value.blank? }
            return unless filtered_attributes.size == required_attributes.size

            filtered_attributes = devise_parameter_filter.filter(filtered_attributes)
            matches = to_adapter.find_all(conditions: filtered_attributes, limit: 2).to_a
            return unless matches.many?

            raise DeviseInvitable::AmbiguousInviteKeyError,
              "Invite key matches multiple #{devise_invitable_base_class.name} records"
          end

          # The random password, as set after an invitation, must conform
          # to any password format validation rules of the application.
          # This default fixes the most common scenarios: Passwords must contain
          # lower + upper case, a digit and a symbol.
          # For more unusual rules, this method can be overridden.
          def random_password
            length = respond_to?(:password_length) ? password_length : Devise.password_length

            prefix = 'aA1!'
            prefix + Devise.friendly_token(length.last - prefix.length)
          end
      end
    end
  end
end
