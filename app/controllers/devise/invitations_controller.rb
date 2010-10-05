class Devise::InvitationsController < ApplicationController
  include Devise::Controllers::InternalHelpers

  before_filter :authenticate_inviter!, :only => [:new, :create]
  before_filter :require_no_authentication, :only => [:edit, :update]
  helper_method :after_sign_in_path_for

  # GET /resource/invitation/new
  def new
    build_resource
    render_with_scope :new
  end

  # POST /resource/invitation
  def create
    self.resource = resource_class.invite!(params[resource_name])

    if resource.errors.empty?
      set_flash_message :notice, :send_instructions, :email => self.resource.email
      redirect_to after_sign_in_path_for(resource_name)
    else
      render_with_scope :new
    end
  end

  # GET /resource/invitation/accept?invitation_token=abcdef
  def edit
    if params[:invitation_token] && self.resource = resource_class.first(:conditions => { :invitation_token => params[:invitation_token] })
      render_with_scope :edit
    else
      set_flash_message(:alert, :invitation_token_invalid)
      redirect_to after_sign_out_path_for(resource_name)
    end
  end

  # PUT /resource/invitation
  def update
    self.resource = resource_class.accept_invitation!(params[resource_name])

    if resource.errors.empty?
      set_flash_message :notice, :updated
      sign_in_and_redirect(resource_name, resource)
    else
      render_with_scope :edit
    end
  end
end
