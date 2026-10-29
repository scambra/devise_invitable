class RestrictedInvitationsController < Devise::InvitationsController
  protected

    def authenticate_inviter!
      return if current_admin

      redirect_back fallback_location: root_path, alert: 'You are not authorized to access this page'
    end
end
