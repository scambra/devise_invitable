module DeviseInvitable
  class Engine < ::Rails::Engine
    
    initializer "devise_invitable.add_url_helpers" do |app|
      ActionController::Base.send :include, DeviseInvitable::Controllers::UrlHelpers
      ActionView::Base.send :include, DeviseInvitable::Controllers::UrlHelpers
    end
    
    initializer "devise_invitable.add_translations" do |app|
      I18n.load_path.unshift File.expand_path(File.join(File.dirname(__FILE__), 'locales', 'en.yml'))
    end

    config.after_initialize do
      Devise::Mailer.send :include, DeviseInvitable::Mailer
    end
    
  end
end
