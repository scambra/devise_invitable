Devise::Controllers::Helpers.module_eval do
  protected
  def authenticate_resource!
    authenticate!(resource_name)
  end
end
