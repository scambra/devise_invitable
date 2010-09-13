module DeviseInvitable::Controllers::Helpers
  protected
  def authenticate_resource!
    send(:"authenticate_#{resource_name}!")
  end
end
ActionController::Base.send :include, DeviseInvitable::Controllers::Helpers
