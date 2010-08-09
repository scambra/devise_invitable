module Devise
  module Controllers
    module InternalHelpers
      # Override Devise's to allow interpolation
      def set_flash_message(key, kind, options = {})
        flash[key] = I18n.t(:"#{resource_name}.#{kind}", { :resource_name => resource_name,
                            :scope => [:devise, controller_name.to_sym], :default => kind }.merge(options))
      end
    end
  end
end
