class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :configure_permitted_parameters, :if => :devise_controller?

  protected
  def after_sign_in_path_for(resource)
    if resource.is_a? Admin
      edit_admin_registration_path(resource)
    else
      super
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:email, :password, :bio) } if defined?(ActionController::StrongParameters)
  end
end
