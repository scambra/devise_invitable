require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "rails/test_unit/railtie"

Bundler.require(:default, :development, DEVISE_ORM) if defined?(Bundler)

begin
  require "#{DEVISE_ORM}/railtie"
rescue LoadError
end

require "devise"
require "devise_invitable"

module RailsApp
  class Application < Rails::Application
    config.autoload_paths += %W[#{config.root}/app/#{DEVISE_ORM}]
    
    config.filter_parameters << :password
    
    config.action_mailer.default_url_options = { :host => "localhost:3000" }
  end
end
