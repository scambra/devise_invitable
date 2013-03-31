class Devise::InvitationsController < DeviseController

  before_filter :authenticate_inviter!, :only => [:new, :create]
  before_filter :has_invitations_left?, :only => [:create]
  before_filter :require_no_authentication, :only => [:edit, :update, :destroy]
  before_filter :resource_from_invitation_token, :only => [:edit, :destroy]
  helper_method :after_sign_in_path_for

  # GET /resource/invitation/new
  def new
    build_resource
    render :new
  end

  # POST /resource/invitation
  def create
    self.resource = resource_class.invite!(resource_params, current_inviter)

    if resource.errors.empty?
      set_flash_message :notice, :send_instructions, :email => self.resource.email
      respond_with resource, :location => after_invite_path_for(resource)
    else
      respond_with_navigational(resource) { render :new }
    end
  end

  # GET /resource/invitation/accept?invitation_token=abcdef
  def edit
    render :edit
  end

  # PUT /resource/invitation
  def update
    self.resource = resource_class.accept_invitation!(update_resource_params)

    if resource.errors.empty?
      flash_message = resource.active_for_authentication? ? :updated : :updated_not_active                                                                                        
      set_flash_message :notice, flash_message
      sign_in(resource_name, resource)
      respond_with resource, :location => after_accept_path_for(resource)
    else
      respond_with_navigational(resource){ render :edit }
    end
  end
  
  # GET /resource/invitation/remove?invitation_token=abcdef
  def destroy
    resource.destroy
    set_flash_message :notice, :invitation_removed
    redirect_to after_sign_out_path_for(resource_name)
  end

  protected
  def current_inviter
    @current_inviter ||= authenticate_inviter!
  end

  def has_invitations_left?
    unless current_inviter.nil? || current_inviter.has_invitations_left?
      build_resource
      set_flash_message :alert, :no_invitations_remaining
      respond_with_navigational(resource) { render :new }
    end
  end
  
  def resource_from_invitation_token
    unless params[:invitation_token] && self.resource = resource_class.to_adapter.find_first(params.slice(:invitation_token))
      set_flash_message(:alert, :invitation_token_invalid)
      redirect_to after_sign_out_path_for(resource_name)
    end
  end

  def update_resource_params
    params.require(resource_name).permit(:invitation_token, :password, :password_confirmation)
  end
  
end

