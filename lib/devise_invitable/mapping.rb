module DeviseInvitable
  module Mapping
    private
    def default_controllers(options)
      options[:controllers] ||= {}
      options[:controllers][:registrations] ||= "devise_invitable/registrations"
      super
    end
  end
end
