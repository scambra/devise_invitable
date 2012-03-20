class Devise::RegistrationsController < Devise::RegistrationsController
  # POST /resource
  def create
    build_resource

    resource = User.new(params[:user])

    @user = User.find_by_email_and_encrypted_password(params[:user][:email], '')
    if @user
      @user.update_attributes(:password => params[:user][:password])
      @user.invitation_token = nil
      resource = @user
    end

    if resource.save
      if resource.active_for_authentication?
        set_flash_message :notice, :signed_up if is_navigational_format?
        sign_in(resource_name, resource)
        respond_with resource, :location => after_sign_up_path_for(resource)
      else
        set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_navigational_format?
        expire_session_data_after_sign_in!
        respond_with resource, :location => after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      respond_with resource
    end
  end
end