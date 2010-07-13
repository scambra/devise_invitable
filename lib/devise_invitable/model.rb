module Devise
  module Models
    # Invitable is responsible to send emails with invitations.
    # Before an invitation is sent to an email, an account is created for it.
    # The invitation email includes a link to set the password, as reset password from recoverable.
    #
    # Configuration:
    #
    #   invite_for: the time you want the user will have to confirm the account after
    #               is invited. When invite_for is zero, the invitation won't expire.
    #               By default invite_for is 0.
    #
    # Examples:
    #
    #   User.find(1).invited?                              # => true/false
    #   User.invite(:email => 'someone@example.com')       # send invitation
    #   User.accept_invitation(:invitation_token => '...') # accept invitation with a token
    #   User.find(1).invite                                # send invitation (again if the user was already invited)
    #   User.find(1).accept_invitation                     # accept invitation
    module Invitable
      extend ActiveSupport::Concern

      # Return true if a user is currently invited, false otherwise
      def invited?
        invitation_token.present?
      end

      # Return true if the user's invitation is still valid
      # (regarding the creation date of the invitation and the invite_for set in devise.rb)
      def valid_invitation?
        invited? && invitation_period_valid?
      end

      # Invite the user and return whether the invitation was successful or not
      # 
      # Invitation consist in:
      # * skip confirmation if the model is confirmable,
      # * generate a new invitation token,
      # * deliver the invitation email
      def invite
        if new_record? || invited?
          self.skip_confirmation! if self.respond_to? :skip_confirmation!
          generate_invitation_token
          save(:validate => self.class.validate_on_invite) && !!deliver_invitation
        end
      end
      def resend_invitation! #:nodoc:
        ActiveSupport::Deprecation.warn ":resend_invitation! is deprecated, please use :invite instead."
        invite
      end

      # Accept an invitation by clearing invitation token
      def accept_invitation
        if invited?
          self.invitation_token = nil
          save
        end
      end
      def accept_invitation! #:nodoc:
        ActiveSupport::Deprecation.warn ":accept_invitation! is deprecated, please use :accept_invitation instead."
        accept_invitation
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

      # Generates a new random token for invitation,
      # and stores the time this token is being generated
      def generate_invitation_token
        self.invitation_token   = Devise.friendly_token
        self.invitation_sent_at = Time.now.utc
      end

      # Overwritting the method in Devise's :confirmable module
      def password_required?
        new_record? || invited? ? false : super
      end

      # Deliver the invitation email
      def deliver_invitation
        ::Devise::Mailer.invitation(self).deliver
      end
      def send_invitation #:nodoc:
        ActiveSupport::Deprecation.warn ":send_invitation is deprecated, please use :deliver_invitation instead."
        deliver_invitation
      end

      module ClassMethods
        # Attempt to find a user by it's email.
        # If no record is found, create a new user and send him an invitation.
        # If a user is found, returns the user with an 'email already taken' error.
        # Options must contain the user email
        def invite(attributes={})
          email = attributes[:email]
          invitable = first(:conditions => { :email => email }) || new(:email => email)
          invitable.attributes = attributes

          if invitable.persisted? && !invitable.invited?
            invitable.errors.add(:email, :taken)
          elsif invitable.email.blank?
            invitable.errors.add(:email, :blank)
          elsif !invitable.email.match Devise.email_regexp
            invitable.errors.add(:email, :invalid)
          else
            invitable.invite
          end

          invitable
        end
        def send_invitation(attributes={}) #:nodoc:
          ActiveSupport::Deprecation.warn ":send_invitation is deprecated, please use :invite instead."
          accept_invitation(attributes)
        end

        # Attempt to find a user by it's invitation_token to set it's password.
        # If a user is found, reset it's password and automatically try saving
        # the record. If no user is found, returns a new user containing an
        # error in invitation_token attribute.
        # Attributes must contain invitation_token, password and confirmation
        def accept_invitation(attributes={})
          invitable = find_or_initialize_with_error_by(:invitation_token, attributes[:invitation_token])
          invitable.attributes = attributes

          if invitable.persisted? && !invitable.valid_invitation?
            invitable.errors.add(:invitation_token, :invalid)
          elsif invitable.errors.empty?
            invitable.accept_invitation
          end
          invitable
        end
        def accept_invitation!(attributes={}) #:nodoc:
          ActiveSupport::Deprecation.warn ":accept_invitation! is deprecated, please use :accept_invitation instead."
          accept_invitation(attributes)
        end

        Devise::Models.config(self, :invite_for)
        Devise::Models.config(self, :validate_on_invite)
      end
    end
  end
end
