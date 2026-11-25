# frozen_string_literal: true

class RestrictedInvitationsController < Devise::InvitationsController
  protected

  def authenticate_inviter!
    return if current_admin

    redirect_back_or_to(root_path, alert: I18n.t('devise.invitations.not_authorized'))
  end
end
