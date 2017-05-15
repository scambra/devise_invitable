ENV["RAILS_ENV"] = "test"
DEVISE_ORM = (ENV["DEVISE_ORM"] || :active_record).to_sym

$:.unshift File.dirname(__FILE__)
puts "\n==> Devise.orm = #{DEVISE_ORM.inspect}"
require "rails_app/config/environment"
require 'rails/test_help'
require "orm/#{DEVISE_ORM}"
require 'capybara/rails'
require 'mocha/setup'

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.default_url_options[:host] = 'test.com'

ActiveSupport::Deprecation.silenced = true
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
    if Rails.version >= '5.0.0'
      self.use_transactional_tests = true
    else
      begin
        require 'test_after_commit' 
        self.use_transactional_fixtures = true
      rescue LoadError
      end
    end
  end
      
  if Rails.version < '5.0.0'
    def post(action, *args)
      hash = args[0] || {}
      super action, hash[:params], hash[:session], hash[:flash]
    end
  end
end
