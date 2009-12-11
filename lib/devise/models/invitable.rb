module Devise
  module Models

    # Invitable is responsible to send emails with invitations.
    # When an invitation is sent to an email, an account is created for it.
    # An invitation has a link to set the password, as reset password from recoverable.
    #
    # Configuration:
    #
    #   invite_for: the time you want the user will have to confirm the account after
    #               is invited. When invite_for is zero, the invitation won't expire.
    #               By default invite_for is 0.
    #
    # Examples:
    #
    #   User.find(1).invited?             # true/false
    #   User.send_invitation(:email => 'someone@example.com') # send invitation
    #   User.accept_invitation!(:invitation_token => '...')   # accept invitation with a token
    #   User.find(1).accept_invitation!   # accept invitation
    #   User.find(1).reset_invitation!    # reset invitation status and send invitation again
    module Invitable

      def self.included(base)
        base.class_eval do
          extend ClassMethods
          callbacks = []
          callbacks.concat before_create_callback_chain.select {|c| c.method == :generate_confirmation_token}
          callbacks.concat after_create_callback_chain.select {|c| c.method == :send_confirmation_instructions}
          callbacks.each do |c|
            c.options[:unless] = lambda{|r| r.class.devise_modules.include?(:invitable) && r.invitation_token}
          end
        end
      end

      # Accept an invitation by clearing invitation token and confirming it if model
      # is confirmable
      def accept_invitation!
        if self.invited?
          self.invitation_token = nil
          if self.class.devise_modules.include? :confirmable
            self.confirm!
          else
            save
          end
        end
      end

      # Verifies whether a user has been invited or not
      def invited?
        !new_record? && !invitation_token.nil?
      end

      # Send invitation by email
      def send_invitation
        ::DeviseMailer.deliver_invitation(self)
      end

      # Reset invitation token and send invitation again
      def reset_invitation!
        if new_record? || invited?
          generate_invitation_token
          save(false)
          send_invitation
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
          self.invitation_token = Devise.friendly_token
          self.invitation_sent_at = Time.now.utc
        end

      module ClassMethods
        # Attempt to find a user by it's email. If a record is not found, create a new
        # user and send invitation to it. If user is found, returns the user with an
        # email already exists error.
        # Options must contain the user email
        def send_invitation(attributes={})
          invitable = find_or_initialize_by_email(attributes[:email])
          if invitable.email.blank?
            invitable.errors.add(:email, :blank)
          elsif invitable.new_record? || invitable.invited?
            invitable.reset_invitation!
          else
            invitable.errors.add(:email, :already_exits, :default => 'already exists')
          end
          invitable
        end

        # Attempt to find a user by it's invitation_token to set it's password.
        # If a user is found, reset it's password and automatically try saving
        # the record. If not user is found, returns a new user containing an
        # error in invitation_token attribute.
        # Attributes must contain invitation_token, password and confirmation
        def accept_invitation!(attributes={})
          invitable = find_or_initialize_with_error_by(:invitation_token, attributes[:invitation_token])
          invitable.errors.add(:invitation_token, :invalid) if attributes[:invitation_token] && !invitable.new_record? && !invitable.valid_invitation?
          if invitable.errors.empty?
            invitable.attributes = attributes
            invitable.accept_invitation! if invitable.valid?
          end
          invitable
        end

        Devise::Models.config(self, :invite_for)
      end
    end
  end
end
