module DeviseInvitable::Controllers::Registrations
  def self.included(controller)
    controller.send :around_filter, :keep_invitation_info, :only => :create
  end

  protected

  def destroy_if_previously_invited
    @invitation_info = {}

    hash = params[resource_name]
    if hash && hash[:email]
      resource = resource_class.where(:email => hash[:email], :encrypted_password => '').first
      if resource
        @invitation_info[:invitation_sent_at] = resource[:invitation_sent_at]
        @invitation_info[:invited_by_id] = resource[:invited_by_id]
        @invitation_info[:invited_by_type] = resource[:invited_by_type]
        resource.destroy
      end
    end
  end
  
  def keep_invitation_info
    resource_invitable = resource_class.devise_modules.include?(:invitable)
    destroy_if_previously_invited if resource_invitable
    yield
    reset_invitation_info if resource_invitable
  end
  
  def reset_invitation_info
    # Restore info about the last invitation (for later reference)
    # Reset the invitation_info only, if invited_by_id is still nil at this stage:
    resource = resource_class.where(:email => params[resource_name][:email], :invited_by_id => nil).first
    if resource
      resource[:invitation_sent_at] = @invitation_info[:invitation_sent_at]
      resource[:invited_by_id] = @invitation_info[:invited_by_id]
      resource[:invited_by_type] = @invitation_info[:invited_by_type]
      resource.save!
    end
  end
end
