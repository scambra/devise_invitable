module Devise::Controllers::Helpers
  protected
  def authenticate_resource!
    send :"authenticate_#{resource_name}!"
  end
end
