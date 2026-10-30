require 'active_support/deprecation'
require 'active_support/security_utils'
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

      attr_accessor :skip_invitation
      attr_accessor :completing_invite
      attr_accessor :registering_directly
      attr_accessor :invited_by_for_next_invitation
      attr_reader   :acceptance_token

      included do
        include ::DeviseInvitable::Inviter
        has_many :devise_invitations,
          as: :invitable,
          class_name: 'DeviseInvitable::Invitation',
          dependent: :nullify,
          autosave: true

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
            joins(:devise_invitations).merge(DeviseInvitable::Invitation.provisioning).distinct
          }
          scope :invitation_not_accepted, lambda {
            joins(:devise_invitations).merge(DeviseInvitable::Invitation.pending)
              .merge(DeviseInvitable::Invitation.provisioning).distinct
          }
          scope :invitation_accepted, lambda {
            joins(:devise_invitations).merge(DeviseInvitable::Invitation.accepted).distinct
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

      def self.required_fields(_klass)
        []
      end

      def current_invitation
        @current_invitation ||=
          if persisted?
            devise_invitations.pending.order(invitation_created_at: :desc).first ||
              devise_invitations.order(invitation_created_at: :desc).first
          end
      end

      def reload(*args)
        @current_invitation = nil
        super
      end

      def invitation_token
        current_invitation&.invitation_token
      end

      def invitation_token=(value)
        current_invitation&.invitation_token = value
      end

      # The public raw token is an encrypted acceptance envelope for new
      # invitations. Before persistence it falls back to the underlying Devise
      # token so invitation callbacks retain their historical behavior.
      def raw_invitation_token
        acceptance_token || @raw_invitation_token
      end

      def invitation_created_at
        current_invitation&.invitation_created_at
      end

      def invitation_created_at=(value)
        assign_invitation_attribute(:invitation_created_at, value)
      end

      def invitation_sent_at
        current_invitation&.invitation_sent_at
      end

      def invitation_sent_at=(value)
        assign_invitation_attribute(:invitation_sent_at, value)
      end

      def invitation_accepted_at
        current_invitation&.invitation_accepted_at
      end

      def invitation_accepted_at=(value)
        assign_invitation_attribute(:invitation_accepted_at, value)
      end

      def invited_by
        if instance_variable_defined?(:@invited_by_for_next_invitation)
          invited_by_for_next_invitation
        else
          current_invitation&.invited_by
        end
      end

      def invited_by=(value)
        if current_invitation
          current_invitation.invited_by = value
        else
          self.invited_by_for_next_invitation = value
        end
      end

      def invited_by_id
        current_invitation&.invited_by_id
      end

      def invited_by_type
        current_invitation&.invited_by_type
      end

      # Accept the current invitation without persisting either record.
      def accept_invitation
        return unless current_invitation

        current_invitation.invitation_accepted_at = Time.now.utc
        current_invitation.invitation_token = nil
      end

      # Save the resource, accept the selected invitation, and resolve the
      # other outstanding invitations for the same invite keys.
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

      def rollback_accepted_invitation(previous_confirmed_at = nil)
        invitation = current_invitation
        invitation.reload if invitation&.persisted?
        self.confirmed_at = previous_confirmed_at if respond_to?(:confirmed_at=)
      end

      # Verify wheather a user is created by invitation, irrespective to invitation status
      def created_by_invite?
        devise_invitations.provisioning.exists?
      end

      def resource_previously_provisioned?
        persisted? && !invitation_pending?
      end

      def accepted_invitation_for_provisioned_resource?
        !!@accepted_invitation_for_provisioned_resource
      end

      # True only while this record is a placeholder created by an unresolved
      # invitation. An active resource may have other pending invitations.
      def invitation_pending?
        return false unless persisted?

        devise_invitations.pending.provisioning.exists?
      end

      def invited_to_sign_up?
        accepting_invitation? || invitation_pending?
      end

      # Returns true if accept_invitation! was called
      def accepting_invitation?
        instance_variable_defined?(:@accepting_invitation) && @accepting_invitation
      end

      # Verifies whether a user accepted an invitation (false when user is accepting it)
      def invitation_accepted?
        !accepting_invitation? && devise_invitations.accepted.exists?
      end

      # Verifies whether a user has accepted an invitation (false when user is accepting it), or was never invited
      def accepted_or_not_invited?
        invitation_accepted? || !invited_to_sign_up?
      end

      # Reset invitation token and send invitation again
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
            generate_acceptance_token
            invitation.invited_by.decrement_invitation_limit! if invitation.invited_by.present?
            deliver_invitation(options) unless skip_invitation
          end
        end
      end

      # Verify whether a invitation is active or not. If the user has been
      # invited, we need to calculate if the invitation time has not expired
      # for this user, in other words, if the invitation is still valid.
      def valid_invitation?
        current_invitation&.pending? && invitation_period_valid?
      end

      # Only verify password when is not invited
      def valid_password?(password)
        super unless !accepting_invitation? && block_from_invitation?
      end

      def active_for_authentication?
        super && !block_from_invitation?
      end

      def inactive_message
        block_from_invitation? ? :invited : super
      end

      # Prevent password changed email when accepting invitation
      def send_password_change_notification?
        super && !accepting_invitation?
      end

      # Enforce password when invitation is being accepted
      def password_required?
        (accepting_invitation? && !resource_previously_provisioned? &&
          self.class.require_password_on_accepting) || super
      end

      def unauthenticated_message
        block_from_invitation? ? :invited : super
      end

      def clear_reset_password_token
        reset_password_token_present = reset_password_token.present?
        super
        accept_invitation! if reset_password_token_present && valid_invitation?
      end

      def clear_errors_on_valid_keys
        self.class.invite_key.each do |key, value|
          self.errors.delete(key) if value === self.send(key)
        end
      end

      # Deliver the invitation email
      def deliver_invitation(options = {})
        generate_invitation_token! unless @raw_invitation_token
        generate_acceptance_token unless acceptance_token
        marked_as_sent = false
        unless current_invitation.invitation_sent_at
          current_invitation.update_attribute :invitation_sent_at, Time.now.utc
          marked_as_sent = true
        end
        delivery = send_devise_notification(:invitation_instructions, acceptance_token, options)
        current_invitation.clear_invite_key!
        delivery
      rescue
        current_invitation.update_attribute(:invitation_sent_at, nil) if marked_as_sent
        raise
      end

      # provide alias to the encrypted invitation_token stored by devise
      def encrypted_invitation_token
        self.invitation_token
      end

      def confirmation_required_for_invited?
        respond_to?(:confirmation_required?, true) && confirmation_required?
      end

      def invitation_due_at
        return nil if (self.class.invite_for == 0 || self.class.invite_for.nil?)

        return unless (time = self.invitation_sent_at)

        time + self.class.invite_for
      end

      def add_taken_error(key)
        errors.add(key, :taken)
      end

      def invitation_taken?
        persisted? && !invitation_pending?
      end

      def revoke_invitation!
        invitation = current_invitation
        return unless invitation&.pending?

        remove_placeholder = invitation.provisioning? && invitation_pending?
        invitation.update!(revoked_at: Time.now.utc, invitation_token: nil)
        destroy if remove_placeholder
      end

      protected

        def assign_invitation_attribute(attribute, value)
          return unless current_invitation

          current_invitation.public_send("#{attribute}=", value)
          current_invitation.save! if current_invitation.persisted?
        end

        def block_from_invitation?
          invitation_pending?
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
          raw, enc = Devise.token_generator.generate(self.class, :invitation_token)
          @raw_invitation_token = raw
          current_invitation.invitation_token = enc
        end

        def generate_invitation_token!
          generate_invitation_token && current_invitation.save!
        end

        def generate_acceptance_token
          @acceptance_token = DeviseInvitable::AcceptanceToken.generate(
            invitation: current_invitation,
            raw_token: @raw_invitation_token,
            invite_key: current_invitation.invite_key_for_acceptance.presence ||
              self.class.normalized_invite_keys(attributes),
            invitation_data: current_invitation.invitation_data
          )
        end

        def new_record_and_responds_to?(method)
          self.new_record? && self.respond_to?(method, true)
        end

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

        def resolve_other_invitations_after_acceptance!(time)
          if self.class.supersede_other_invitations_on_accept
            supersede_other_invitations!(time)
          else
            preserve_other_invitations!
          end
        end

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

        def preserve_other_invitations!
          self.class.pending_invitations_for(attributes).each do |invitation|
            next if invitation.id == current_invitation.id

            invitation.invitable = self
            invitation.resource_created_at = nil if current_invitation.provisioning?
            invitation.save!
          end
        end

        def resolve_invitations_after_registration!
          self.class.pending_invitations_for(attributes).each do |invitation|
            invitation.update!(
              invitable: self,
              invitation_token: nil,
              superseded_at: Time.now.utc,
              superseded_reason: 'registered'
            )
          end
          self.registering_directly = false
        end

      module ClassMethods
        def devise_invitable_base_class
          if respond_to?(:base_class)
            base_class
          elsif respond_to?(:root_class)
            root_class
          else
            self
          end
        end

        # Return fields to invite
        def invite_key_fields
          invite_key.keys
        end

        # Attempt to find a user by its email. If a record is not found,
        # create a new user and send an invitation to it. If the user is found,
        # return the user with an email already exists error.
        # If the user is found and still has a pending invitation, invitation
        # email is resent unless resend_invitation is set to false.
        # Attributes must contain the user's email, other attributes will be
        # set in the record
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

        def invite!(attributes = {}, invited_by = nil, options = {}, &block)
          attr_hash = ActiveSupport::HashWithIndifferentAccess.new(attributes.to_h)
          _invite(attr_hash, invited_by, options, &block).first
        end

        def invite_mail!(attributes = {}, invited_by = nil, options = {}, &block)
          _invite(attributes, invited_by, options, &block).last
        end

        # Attempt to find a user by it's invitation_token to set it's password.
        # If a user is found, reset it's password and automatically try saving
        # the record. If not user is found, returns a new user containing an
        # error in invitation_token attribute.
        # Attributes must contain invitation_token, password and confirmation
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

        def pending_invitations_for(attributes)
          keys = normalized_invite_keys(attributes)
          digest = DeviseInvitable::Invitation.digest_for(devise_invitable_base_class.name, keys)
          DeviseInvitable::Invitation.pending.where(
            invitable_type: devise_invitable_base_class.name,
            invite_key_digest: digest
          ).to_a
        end

        def normalized_invite_keys(attributes)
          attributes.to_h.with_indifferent_access.slice(*invite_key_fields).each_with_object({}) do |(key, value), keys|
            value = value.to_s.strip if strip_whitespace_keys.include?(key.to_sym)
            value = value.downcase if value.respond_to?(:downcase) && case_insensitive_keys.include?(key.to_sym)
            keys[key] = value
          end
        end

        # Callback convenience methods
        def before_invitation_created(*args, &blk)
          set_callback(:invitation_created, :before, *args, &blk)
        end

        def after_invitation_created(*args, &blk)
          set_callback(:invitation_created, :after, *args, &blk)
        end

        def before_invitation_accepted(*args, &blk)
          set_callback(:invitation_accepted, :before, *args, &blk)
        end

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
        Devise::Models.config(self, :supersede_other_invitations_on_accept)

        def invited_by_class_name=(value)
          DeviseInvitable.warn_deprecated_invited_by_setting(:invited_by_class_name)
          @invited_by_class_name = value
        end

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
            invitation = DeviseInvitable::Invitation.where(
              id: payload[:invitation_id],
              invitable_type: devise_invitable_base_class.name,
              invitation_token: invitation_token
            ).first
            invitation.invitation_data = payload[:invitation_data] || {} if invitation
            invite_key = normalized_invite_keys(payload[:invite_key] || {})
            expected_digest = DeviseInvitable::Invitation.digest_for(
              devise_invitable_base_class.name,
              invite_key
            )
            invitation = nil unless invitation &&
              ActiveSupport::SecurityUtils.secure_compare(
                invitation.invite_key_digest,
                expected_digest
              )
            [invitation, invite_key]
          end

          def legacy_invitation_and_key(original_token)
            invitation_token = Devise.token_generator.digest(self, :invitation_token, original_token)
            invitation = DeviseInvitable::Invitation.where(
              invitable_type: devise_invitable_base_class.name,
              invitation_token: invitation_token
            ).first
            [invitation, invitation&.invite_key]
          end

          def ensure_unique_invite_key_match!(required_attributes, attributes)
            filtered_attributes = attributes.to_h.with_indifferent_access
              .slice(*required_attributes)
              .delete_if { |_key, value| value.blank? }
            return unless filtered_attributes.size == required_attributes.size

            filtered_attributes = devise_parameter_filter.filter(filtered_attributes)
            matches = where(filtered_attributes).limit(2).to_a
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
