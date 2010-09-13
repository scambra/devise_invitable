module DeviseInvitable
  class Engine < ::Rails::Engine
    
    ActiveSupport.on_load(:action_controller) { include DeviseInvitable::Controllers::UrlHelpers }
    ActiveSupport.on_load(:action_view) { include DeviseInvitable::Controllers::UrlHelpers }
    
    config.after_initialize do
      Devise::Mailer.send :include, DeviseInvitable::Mailer
    end
    
  end
end
