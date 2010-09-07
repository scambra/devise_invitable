require 'devise/models'

module Devise
  module Models
    # Invitable is responsible to send emails with invitations.
    # Before an invitation is sent to an email, an account is created for it.
    # The invitation email includes a link to set the password, as is the
    # Devise's module: recoverable.
    #
    # Configuration:
    #
    #   invite_for: the time you want the user will have to confirm the account
    #               after is invited. When invite_for is zero, the invitation
    #               won't expire. (default: 0).
    module Invitable
      extend ActiveSupport::Concern
      
      # Public: Indicates weither the record is currently invited.
      #
      # Examples
      #
      #   user = User.invite(:email => 'someone@example.com')
      #   user.invited?
      #   # => true
      #
      #   user = User.create(:email => 'someone@example.com')
      #   user.invited?
      #   # => false
      #
      # Returns a Boolean that indicates if the record is currently invited.
      def invited?
        invitation_token.present?
      end
      
      # Public: Indicates if a record's invitation is valid
      #
      # Examples
      #
      #   user = User.invite(:email => 'someone@example.com')
      #   user.valid_invitation?
      #   # => true
      #
      #   user = User.create(:email => 'someone@example.com')
      #   user.valid_invitation?
      #   # => false
      #
      # Returns the validity of the record's invitation as a Boolean. Validity 
      #   is relative to the invitation date and the invite_for set in
      #   devise.rb. False is returned if the record is not currently invited.
      def valid_invitation?
        invited? && invitation_period_valid?
      end
      
      # Public: Invite the record by sending it an email.
      #
      # Examples
      #
      #   User.new(:email => 'someone@example.com').invite
      #
      #   user = User.invite(:email => 'someone@example.com')
      #   user.invite
      #   # => send a new invitation to this user (with a new invitation token)
      #
      # Returns the success of the invitation as a Boolean.
      def invite
        if new_record? || invited?
          @skip_password = true
          self.skip_confirmation! if self.respond_to? :skip_confirmation!
          generate_invitation_token unless !valid? && self.class.validate_on_invite
          save(:validate => self.class.validate_on_invite) && !!deliver_invitation
        end
      end
      def resend_invitation!
        ActiveSupport::Deprecation.warn ":resend_invitation! is deprecated, please use :invite instead."
        invite
      end
      
      # Public: Accept the record's current invitation. The invitation can be
      # accepted only if the record has set a password.
      #
      # Examples
      #
      #   # Valid acceptation.
      #   user = User.invite(:email => 'someone@example.com')
      #   user.password = '123456'
      #   user.accept_invitation
      #   # => true
      #
      #   # Nil password.
      #   user = User.invite(:email => 'someone@example.com')
      #   user.accept_invitation
      #   # => false
      #
      #   # Not an invited user.
      #   user = User.create(:email => 'someone@example.com')
      #   user.accept_invitation
      #   # => false
      #
      # Returns the success of the invitation acceptation as a Boolean.
      def accept_invitation
        @skip_password = false
        if invited? && valid?
          clear_invitation_token
          save
        else
          false
        end
      end
      def accept_invitation!
        ActiveSupport::Deprecation.warn ":accept_invitation! is deprecated, please use :accept_invitation instead."
        accept_invitation
      end
      
    private
      
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
      
      # Overwritting the method in Devise's :validatable module
      def password_required?
        !@skip_password && (invited? || !persisted? || !password.nil? || !password_confirmation.nil?)
      end
      
      # Deliver the invitation email
      def deliver_invitation
        ::Devise.mailer.invitation_instructions(self).deliver
      end
      
      def clear_invitation_token
        self.invitation_token = nil
      end
      
      module ClassMethods
        # Public: Send an invitation email to a given email. Invitation can only
        # be sent to email that are not already in the database, or to email
        # that are already invited.
        #
        # attributes - A Hash of attributes to set for the record (default: {}):
        #              :email - The String email to which to send the invitation
        #                       email.
        #
        # Example
        #
        #   User.invite(:email => 'someone@example.com')
        #   # => send an invitation to this email
        # 
        # Returns a record, if it has no errors, the invitation has been sent
        #   to its email.
        def invite(attributes = {})
          invitable = find_or_initialize_with_error_by(:email, attributes[:email])
          invitable.attributes = attributes
          
          if invitable.persisted? && !invitable.invited?
            invitable.errors.add(:email, :taken)
          elsif invitable.email.present? && invitable.email.match(Devise.email_regexp)
            invitable.invite
          end
          
          invitable
        end
        def send_invitation(attributes = {})
          ActiveSupport::Deprecation.warn ":send_invitation is deprecated, please use :invite instead."
          accept_invitation(attributes)
        end
        
        # Accept an invitation for a record that has the given invitation_token.
        #
        # attributes - A Hash of attributes to set for the record (default: {}):
        #              :invitation_token - The invitation_token used to retrieve
        #                                  the invitation.
        #              :password - The new password to set.
        #              :password_confirmation - The password confirmation
        #                                       (optional).
        #
        # Example
        #
        #   User.accept_invitation(:invitation_token => '...',
        #                          :password => 'abc123')
        #   # => set the password for the user with this invitation_token
        #
        # Return a record, if it has no errors, the invitation has been
        #   accepted.
        def accept_invitation(attributes = {})
          invitable = find_or_initialize_with_error_by(:invitation_token, attributes[:invitation_token])
          invitable.attributes = attributes
          
          if invitable.persisted? && !invitable.valid_invitation?
            invitable.errors.add(:invitation_token, :invalid)
          elsif invitable.errors.empty?
            invitable.accept_invitation
          end
          invitable
        end
        def accept_invitation!(attributes = {})
          ActiveSupport::Deprecation.warn ":accept_invitation! is deprecated, please use :accept_invitation instead."
          accept_invitation(attributes)
        end
        
        Devise::Models.config(self, :invite_for)
        Devise::Models.config(self, :validate_on_invite)
      end
      
    end
  end
end