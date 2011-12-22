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
    #   User.find(1).invited?                               # => true/false
    #   User.invite!(:email => 'someone@example.com')       # => send invitation
    #   User.accept_invitation!(:invitation_token => '...') # => accept invitation with a token
    #   User.find(1).accept_invitation!                     # => accept invitation
    #   User.find(1).invite!                                # => reset invitation status and send invitation again
    module Invitable
      extend ActiveSupport::Concern

      attr_accessor :skip_invitation

      included do
        include ::DeviseInvitable::Inviter        
        belongs_to :invited_by, :polymorphic => true
        
        include ActiveSupport::Callbacks
        define_callbacks :invitation_accepted
      end

      # Accept an invitation by clearing invitation token and confirming it if model
      # is confirmable
      def accept_invitation!
        if self.invited? && self.valid?
          run_callbacks :invitation_accepted do
            self.invitation_token = nil
            self.invitation_accepted_at = Time.now.utc if respond_to? :"invitation_accepted_at="
            self.save(:validate => false)
          end
        end
      end

      # Verifies whether a user has been invited or not
      def invited?
        persisted? && invitation_token.present?
      end

      # Reset invitation token and send invitation again
      def invite!
        @skip_password = true
        was_invited = invited?
        self.skip_confirmation! if self.new_record? && self.respond_to?(:skip_confirmation!)
        generate_invitation_token if self.invitation_token.nil?
        self.invitation_sent_at = Time.now.utc
        if save(:validate => false)
          self.invited_by.decrement_invitation_limit! if !was_invited and self.invited_by.present?
          deliver_invitation unless @skip_invitation
        end
      end

      # Verify whether a invitation is active or not. If the user has been
      # invited, we need to calculate if the invitation time has not expired
      # for this user, in other words, if the invitation is still valid.
      def valid_invitation?
        invited? && invitation_period_valid?
      end

      # Only verify password when is not invited
      def valid_password?(password)
        super unless invited?
      end

      protected
        # Overriding the method in Devise's :validatable module so password is not required on inviting
        def password_required?
          !@skip_password && super
        end

        # Deliver the invitation email
        def deliver_invitation
          ::Devise.mailer.invitation_instructions(self).deliver
        end

        # Clear invitation token when reset password token is cleared too
        def clear_reset_password_token
          self.invitation_token = nil if invited?
          super
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
          invitation_sent_at && (self.class.invite_for.to_i.zero? || invitation_sent_at.utc >= self.class.invite_for.ago)
        end

        # Generates a new random token for invitation, and stores the time
        # this token is being generated
        def generate_invitation_token
          self.invitation_token   = self.class.invitation_token
        end

      module ClassMethods
        # Attempt to find a user by it's email. If a record is not found, create a new
        # user and send invitation to it. If user is found, returns the user with an
        # email already exists error.
        # If user is found and still have pending invitation, email is resend unless
        # resend_invitation is set to false
        # Attributes must contain the user email, other attributes will be set in the record
        def _invite(attributes={}, invited_by=nil, &block)
          invitable = find_or_initialize_with_error_by(invite_key, attributes.delete(invite_key))
          invitable.assign_attributes(attributes, :as => inviter_role(invited_by))
          invitable.invited_by = invited_by

          invitable.valid? if self.validate_on_invite
          invitable.errors[:password].clear if self.validate_on_invite
          if invitable.new_record?
            invitable.errors.clear if !self.validate_on_invite and invitable.email.try(:match, Devise.email_regexp)
          else
            invitable.errors.add(invite_key, :taken) unless invitable.invited? && self.resend_invitation
          end

          if invitable.errors.empty?
            yield invitable if block_given?
            mail = invitable.invite!
          end
          [invitable, mail]
        end
        
        # Override this method if the invitable is using Mass Assignment Security
        # and the inviter has a non-default role.
        def inviter_role(inviter)
          :default
        end

        def invite!(attributes={}, invited_by=nil, &block)
          invitable, mail = _invite(attributes, invited_by, &block)
          invitable
        end

        def invite_mail!(attributes={}, invited_by=nil, &block)
          invitable, mail = _invite(attributes, invited_by, &block)
          mail
        end

        # Attempt to find a user by it's invitation_token to set it's password.
        # If a user is found, reset it's password and automatically try saving
        # the record. If not user is found, returns a new user containing an
        # error in invitation_token attribute.
        # Attributes must contain invitation_token, password and confirmation
        def accept_invitation!(attributes={})
          invitable = find_or_initialize_with_error_by(:invitation_token, attributes.delete(:invitation_token))
          invitable.errors.add(:invitation_token, :invalid) if invitable.invitation_token && invitable.persisted? && !invitable.valid_invitation?
          if invitable.errors.empty?
            invitable.attributes = attributes
            invitable.accept_invitation!
          end
          invitable
        end

        # Generate a token checking if one does not already exist in the database.
        def invitation_token
          generate_token(:invitation_token)
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
      end
    end
  end
end

