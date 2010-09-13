module DeviseInvitable
  class Engine < ::Rails::Engine
    
    initializer "devise_invitable.add_url_helpers" do |app|
      ActionController::Base.send :include, DeviseInvitable::Controllers::UrlHelpers
      ActionView::Base.send :include, DeviseInvitable::Controllers::UrlHelpers
    end
    
    config.after_initialize do
      Devise::Mailer.send :include, DeviseInvitable::Mailer
    end
    
  end
end
