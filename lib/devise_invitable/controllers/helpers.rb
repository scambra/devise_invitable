module DeviseInvitable::Controllers::Helpers
  extend ActiveSupport::Concern

  included do
    hide_action :after_invite_path_for, :after_accept_path_for
  end
  
  def after_invite_path_for(resource)
    after_sign_in_path_for(resource)
  end
  
  def after_accept_path_for(resource)
    after_sign_in_path_for(resource)
  end
  
  protected
  def authenticate_inviter!
    send(:"authenticate_#{resource_name}!", :force => true)
  end
  
end

