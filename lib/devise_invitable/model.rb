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

      included do
        belongs_to :invited_by, :polymorphic => true
      end

      # Accept an invitation by clearing invitation token and confirming it if model
      # is confirmable
      def accept_invitation!
        if self.invited? && self.valid?
          self.invitation_token = nil
          self.save
        end
      end

      # Verifies whether a user has been invited or not
      def invited?
        persisted? && invitation_token.present?
      end

      # Return true if this user has invitations left to send
      def has_invitations_left?
        if self.class.invitation_limit.present?
          if invitation_limit
            return invitation_limit > 0
          else
            return self.class.invitation_limit > 0
          end
        else
          return true
        end
      end

      # Reset invitation token and send invitation again
      def invite!
        if new_record? || invited?
          self.skip_confirmation! if self.new_record? && self.respond_to?(:skip_confirmation!)
          generate_invitation_token if self.invitation_token.nil?
          self.invitation_sent_at = Time.now.utc
          save(:validate => false)
          ::Devise.mailer.invitation_instructions(self).deliver
        end
      end

      # Verify whether a invitation is active or not. If the user has been
      # invited, we need to calculate if the invitation time has not expired
      # for this user, in other words, if the invitation is still valid.
      def valid_invitation?
        invited? && invitation_period_valid?
      end

      protected

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
        # Attributes must contain the user email, other attributes will be set in the record
        def invite!(attributes={}, invited_by=nil)
          invitable = find_or_initialize_with_error_by(:email, attributes.delete(:email))
          invitable.attributes = attributes
          invitable.invited_by = invited_by

          if invitable.new_record?
            invitable.errors.clear if invitable.email.try(:match, Devise.email_regexp)
          else
            invitable.errors.add(:email, :taken) unless invitable.invited?
          end

          invitable.invite! if invitable.errors.empty?
          invitable
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

        Devise::Models.config(self, :invite_for)
        Devise::Models.config(self, :invitation_limit)
      end
    end
  end
end
