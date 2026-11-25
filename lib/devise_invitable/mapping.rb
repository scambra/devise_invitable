# frozen_string_literal: true

module DeviseInvitable
  # Adds invitation controllers to Devise mappings.
  module Mapping
    private

    def default_controllers(options)
      unless options[:module]
        options[:controllers] ||= {}
        options[:controllers][:registrations] ||= 'devise_invitable/registrations'
      end
      super
    end
  end
end
