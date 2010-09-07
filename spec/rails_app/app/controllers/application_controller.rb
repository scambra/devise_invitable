class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :current_user
  before_filter :authenticate_user!, :if => :devise_controller?
end