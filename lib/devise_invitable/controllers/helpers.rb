module DeviseInvitable::Controllers::Helpers
  extend ActiveSupport::Concern

  included do
  end

  # Returns the path used after +invitee+ is invited. By default this is the
  # inviter's signed-in root path.
  def after_invite_path_for(inviter, invitee = nil)
    signed_in_root_path(inviter)
  end

  # Returns the path used after +resource+ accepts an invitation. By default
  # this is the resource's signed-in root path.
  def after_accept_path_for(resource)
    signed_in_root_path(resource)
  end

  # Returns the redirect path used when an invitation token is missing or
  # invalid. By default this is the resource's signed-out path.
  def invalid_token_path_for(resource_name)
    after_sign_out_path_for(resource_name)
  end

  protected

    def authenticate_inviter!
      send(:"authenticate_#{resource_name}!", force: true)
    end
end

