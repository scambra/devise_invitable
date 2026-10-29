class BooleanInviterInvitationsController < Devise::InvitationsController
  protected

    def authenticate_inviter!
      true
    end

    def current_user
      User.find_by(email: 'boolean-inviter@example.com')
    end
end
