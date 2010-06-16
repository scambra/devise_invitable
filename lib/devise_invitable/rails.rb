module DeviseInvitable
  class Engine < ::Rails::Engine
    paths.lib = "lib" 
    config.after_initialize do
      I18n.load_path.unshift File.expand_path(File.join(File.dirname(__FILE__), 'locales', 'en.yml'))
      Devise::Mailer.send :include, DeviseInvitable::Mailer
    end
    
  end
end
