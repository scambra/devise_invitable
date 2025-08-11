ENV['RAILS_ENV'] = 'test'
DEVISE_ORM = (ENV['DEVISE_ORM'] || :active_record).to_sym

$:.unshift File.dirname(__FILE__)
puts "\n==> Devise.orm = #{DEVISE_ORM.inspect}"
require "rails_app/config/environment"
require 'rails/test_help'
require "orm/#{DEVISE_ORM}"
require 'capybara/rails'
require 'mocha/minitest'

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.default_url_options[:host] = 'example.com'

if ActiveSupport::Deprecation.respond_to?(:silenced=)
  ActiveSupport::Deprecation.silenced = true
end
$VERBOSE = false

class ActionDispatch::IntegrationTest
  include Capybara::DSL
end

class ActionController::TestCase
  if defined? Devise::Test
    include Devise::Test::ControllerHelpers
  else
    include Devise::TestHelpers
  end

  if defined? ActiveRecord
    self.use_transactional_tests = true
  end
end

# This is a workaround for the issue with Rails 8.0 and lazy loading of routes.
# see: https://github.com/heartcombo/devise/issues/5705
if Rails.gem_version >= Gem::Version.new('8.0')
  Rails.application.routes_reloader.execute_unless_loaded
end
