require 'active_support/deprecation'

module Devise
  module Models
    # Invitable is responsible for sending invitation emails.
    # When an invitation is sent to an email address, an account is created for it.
    # Invitation email contains a link allowing the user to accept the invitation
    # by setting a password (as reset password from Devise's recoverable module).
    #
    # Configuration:
    #
    #   invite_for: The period the generated invitation token is valid, after
    #               this period, the invited resource won't be able to accept the invitation.
    #               When invite_for is 0 (the default), the invitation won't expire.
    #
    # Examples:
    #
    #   User.find(1).invited_to_sign_up?                    # => true/false
    #   User.invite!(:email => 'someone@example.com')       # => send invitation
    #   User.accept_invitation!(:invitation_token => '...') # => accept invitation with a token
    #   User.find(1).accept_invitation!                     # => accept invitation
    #   User.find(1).invite!                                # => reset invitation status and send invitation again
    module Invitable
      extend ActiveSupport::Concern

      attr_accessor :skip_invitation
      attr_accessor :completing_invite
      attr_reader   :raw_invitation_token

      included do
        include ::DeviseInvitable::Inviter
        belongs_to_options = if Devise.invited_by_class_name
          {:class_name => Devise.invited_by_class_name}
        else
          {:polymorphic => true}
        end
        if defined?(ActiveRecord) && defined?(ActiveRecord::Base) && self < ActiveRecord::Base
          counter_cache = Devise.invited_by_counter_cache
          belongs_to_options.merge! :counter_cache => counter_cache if counter_cache
        end
        belongs_to :invited_by, belongs_to_options

        include ActiveSupport::Callbacks
        define_callbacks :invitation_accepted

        attr_writer :skip_password

        scope :no_active_invitation, lambda { where(:invitation_token => nil) }
        if defined?(Mongoid) && defined?(Mongoid::Document) && self < Mongoid::Document
          scope :invitation_not_accepted, lambda { where(:invitation_accepted_at => nil, :invitation_token.ne => nil) }
          scope :invitation_accepted, lambda { where(:invitation_accepted_at.ne => nil) }
        else
          scope :invitation_not_accepted, lambda { where(arel_table[:invitation_token].not_eq(nil)).where(:invitation_accepted_at => nil) }
          scope :invitation_accepted, lambda { where(arel_table[:invitation_accepted_at].not_eq(nil)) }

          [:before_invitation_accepted, :after_invitation_accepted].each do |callback_method|
            send callback_method
          end
        end
      end

      def self.required_fields(klass)
        fields = [:invitation_token, :invitation_created_at, :invitation_sent_at, :invitation_accepted_at,
         :invitation_limit, :invited_by_id, :invited_by_type]
        fields << :invitations_count if defined?(ActiveRecord) && self < ActiveRecord::Base
        fields -= [:invited_by_type] if Devise.invited_by_class_name
        fields
      end

      # Accept an invitation by clearing invitation token and and setting invitation_accepted_at
      def accept_invitation
        self.invitation_accepted_at = Time.now.utc
        self.invitation_token = nil
      end

      # Accept an invitation by clearing invitation token and and setting invitation_accepted_at
      # Saves the model and confirms it if model is confirmable, running invitation_accepted callbacks
      def accept_invitation!
        if self.invited_to_sign_up? && self.valid?
          run_callbacks :invitation_accepted do
            self.accept_invitation
            self.confirmed_at = self.invitation_accepted_at if self.respond_to?(:confirmed_at)
            self.save(:validate => false)
          end
        end
      end

      # Verifies whether a user has been invited or not
      def invited_to_sign_up?
        persisted? && invitation_token.present?
      end

      # Verifies whether a user accepted an invitation (or is accepting it)
      def invitation_accepted?
        invitation_accepted_at.present?
      end

      # Verifies whether a user has accepted an invitation (or is accepting it), or was never invited
      def accepted_or_not_invited?
        invitation_accepted? || !invited_to_sign_up?
      end

      # Reset invitation token and send invitation again
      def invite!(invited_by = nil)
        was_invited = invited_to_sign_up?

        # Required to workaround confirmable model's confirmation_required? method
        # being implemented to check for non-nil value of confirmed_at
        if self.new_record? && self.respond_to?(:confirmation_required?, true)
          def self.confirmation_required?; false; end
        end

        yield self if block_given?
        generate_invitation_token if self.invitation_token.nil? || (!skip_invitation || @raw_invitation_token.nil?)
        self.invitation_created_at = Time.now.utc
        self.invitation_sent_at = self.invitation_created_at unless skip_invitation
        self.invited_by = invited_by if invited_by

        # Call these before_validate methods since we aren't validating on save
        self.downcase_keys if self.new_record? && self.respond_to?(:downcase_keys, true)
        self.strip_whitespace if self.new_record? && self.respond_to?(:strip_whitespace, true)

        if save(:validate => false)
          self.invited_by.decrement_invitation_limit! if !was_invited and self.invited_by.present?
          deliver_invitation unless skip_invitation
        end
      end

      # Verify whether a invitation is active or not. If the user has been
      # invited, we need to calculate if the invitation time has not expired
      # for this user, in other words, if the invitation is still valid.
      def valid_invitation?
        invited_to_sign_up? && invitation_period_valid?
      end

      # Only verify password when is not invited
      def valid_password?(password)
        super unless block_from_invitation?
      end

      def unauthenticated_message
        block_from_invitation? ? :invited : super
      end

      def after_password_reset
        super
        accept_invitation! if invited_to_sign_up?
      end

      def clear_errors_on_valid_keys
        self.class.invite_key.each do |key, value|
          self.errors.delete(key) if value === self.send(key)
        end
      end

      # Deliver the invitation email
      def deliver_invitation
        generate_invitation_token! unless @raw_invitation_token
        self.update_attribute :invitation_sent_at, Time.now.utc unless self.invitation_sent_at
        send_devise_notification(:invitation_instructions, @raw_invitation_token)
      end

      # provide alias to the encrypted invitation_token stored by devise
      def encrypted_invitation_token
        self.invitation_token
      end

      def confirmation_required_for_invited?
        respond_to?(:confirmation_required?, true) && confirmation_required?
      end

      protected
        # Overriding the method in Devise's :validatable module so password is not required on inviting
        def password_required?
          !skip_password && super
        end

        def skip_password
          @skip_password ||= false
        end

        def block_from_invitation?
          invited_to_sign_up?
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
          time = invitation_created_at || invitation_sent_at
          time && (self.class.invite_for.to_i.zero? || time.utc >= self.class.invite_for.ago)
        end

        # Generates a new random token for invitation, and stores the time
        # this token is being generated
        def generate_invitation_token
          raw, enc = Devise.token_generator.generate(self.class, :invitation_token)
          @raw_invitation_token = raw
          self.invitation_token = enc
        end

        def generate_invitation_token!
          generate_invitation_token && save(:validate => false)
        end

      module ClassMethods
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
        def _invite(attributes={}, invited_by=nil, &block)
          invite_key_array = invite_key_fields
          attributes_hash = {}
          invite_key_array.each do |k,v|
            attribute = attributes.delete(k)
            attribute = attribute.to_s.strip if strip_whitespace_keys.include?(k)
            attributes_hash[k] = attribute
          end

          invitable = find_or_initialize_with_errors(invite_key_array, attributes_hash)
          invitable.assign_attributes(attributes)
          invitable.invited_by = invited_by

          invitable.skip_password = true
          invitable.valid? if self.validate_on_invite
          if invitable.new_record?
            invitable.clear_errors_on_valid_keys if !self.validate_on_invite
          elsif !invitable.invited_to_sign_up? || !self.resend_invitation
            invite_key_array.each do |key|
              invitable.errors.add(key, :taken)
            end
          end

          yield invitable if block_given?
          mail = invitable.invite! if invitable.errors.empty?
          [invitable, mail]
        end

        def invite!(attributes={}, invited_by=nil, &block)
          _invite(attributes.with_indifferent_access, invited_by, &block).first
        end

        def invite_mail!(attributes={}, invited_by=nil, &block)
          _invite(attributes, invited_by, &block).last
        end

        # Attempt to find a user by it's invitation_token to set it's password.
        # If a user is found, reset it's password and automatically try saving
        # the record. If not user is found, returns a new user containing an
        # error in invitation_token attribute.
        # Attributes must contain invitation_token, password and confirmation
        def accept_invitation!(attributes={})
          original_token = attributes.delete(:invitation_token)
          invitable = find_by_invitation_token(original_token, false)
          if invitable.errors.empty?
            invitable.assign_attributes(attributes)
            invitable.accept_invitation!
          end
          invitable
        end

        def find_by_invitation_token(original_token, only_valid)
          invitation_token = Devise.token_generator.digest(self, :invitation_token, original_token)

          invitable = find_or_initialize_with_error_by(:invitation_token, invitation_token)
          invitable.errors.add(:invitation_token, :invalid) if invitable.invitation_token && invitable.persisted? && !invitable.valid_invitation?
          invitable.invitation_token = original_token
          invitable unless only_valid && invitable.errors.present?
        end

        # Callback convenience methods
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
        Devise::Models.config(self, :allow_insecure_sign_in_after_accept)
      end
    end
  end
end

