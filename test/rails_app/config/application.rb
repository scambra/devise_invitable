require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "action_mailer/railtie"
require "rails/test_unit/railtie"

Bundler.require(:default, DEVISE_ORM) if defined?(Bundler)

begin
  require "#{DEVISE_ORM}/railtie"
rescue LoadError
end
PARENT_MODEL_CLASS = DEVISE_ORM == :active_record ? ActiveRecord::Base : Object
Mongoid.load!(File.expand_path('../../mongoid.yml', __FILE__)) if DEVISE_ORM == :mongoid && Mongoid::VERSION < '3.0.0'

require "devise"
require "devise_invitable"

module RailsApp
  class Application < Rails::Application
    config.filter_parameters << :password
    config.action_mailer.default_url_options = { :host => "localhost:3000" }
    config.i18n.enforce_available_locales = true
  end
end
