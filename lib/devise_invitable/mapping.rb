module DeviseInvitable
  module Mapping
    def self.included(base)
      base.alias_method_chain :default_controllers, :invitable
    end
    
    private
    def default_controllers_with_invitable(options)
      options[:controllers] ||= {}
      options[:controllers][:registrations] ||= "devise_invitable/registrations"
      default_controllers_without_invitable(options)
    end
  end
end