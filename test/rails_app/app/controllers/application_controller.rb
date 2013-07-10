class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :configure_permitted_parameters, :if => :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:email, :password, :bio) } if defined?(ActionController::StrongParameters)
  end
end
