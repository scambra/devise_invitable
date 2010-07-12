# Include UrlHelpers in ActionController and ActionView as soon as they are loaded.
ActiveSupport.on_load(:action_controller) { include DeviseInvitable::Controllers::UrlHelpers }
ActiveSupport.on_load(:action_view) { include DeviseInvitable::Controllers::UrlHelpers }

module DeviseInvitable
  class Engine < ::Rails::Engine

    config.after_initialize do
      Devise::Mailer.send :include, DeviseInvitable::Mailer
    end
    
  end
end
