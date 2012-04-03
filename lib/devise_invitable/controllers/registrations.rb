module DeviseInvitable::Controllers::Registrations
  def self.included(controller)
    controller.send :around_filter, :destroy_if_previously_invited, :only => :create
  end

  protected

  def destroy_if_previously_invited
    invitation_info = {}

    hash = params[resource_name]
    if hash && hash[:email]
      resource = resource_class.first(:conditions => { :email => hash[:email], :encrypted_password => '' })
      if resource
        invitation_info[:invitation_sent_at] = resource[:invitation_sent_at]
        invitation_info[:invited_by_id] = resource[:invited_by_id]
        invitation_info[:invited_by_type] = resource[:invited_by_type]
        resource.destroy
      end
    end

    # execute the action (create)
    yield
    # Note that the after_filter is executed at THIS position !

    # Restore info about the last invitation (for later reference)
    # Reset the invitation_info only, if invited_by_id is still nil at this stage:
    resource = resource_class.first(:conditions => { :email => hash[:email], :invited_by_id => nil })
    if resource
      resource[:invitation_sent_at] = invitation_info[:invitation_sent_at]
      resource[:invited_by_id] = invitation_info[:invited_by_id]
      resource[:invited_by_type] = invitation_info[:invited_by_type]
      resource.save!
    end
  end
end