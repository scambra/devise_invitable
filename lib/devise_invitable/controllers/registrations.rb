module DeviseInvitable::Controllers::Registrations
  def self.included(controller)
    controller.alias_method_chain :build_resource, :invitation
  end

  protected

  def build_resource_with_invitation(*args)
    hash = args.pop || resource_params || {}
    if hash[:email]
      self.resource = resource_class.where(:email => hash[:email], :encrypted_password => '').first
      if self.resource
        self.resource.attributes = hash
        self.resource.accept_invitation!
      end
    end
    self.resource ||= build_resource_without_invitation(hash, *args)
  end
end
