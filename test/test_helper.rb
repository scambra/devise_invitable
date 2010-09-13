ENV["RAILS_ENV"] = "test"
require 'rails_app/config/environment'

require 'rails/test_help'
require 'mocha'
require 'webrat'
require 'webrat/core/matchers'

ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.default_url_options[:host] = 'test.com'

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(nil)

ActiveRecord::Schema.define(:version => 1) do
  create_table :users do |t|
    t.database_authenticatable :null => true
    t.string :username
    t.confirmable
    t.invitable

    t.timestamps
  end
end

Webrat.configure do |config|
  config.mode = :rack
  config.open_error_files = false
end

class ActiveSupport::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  def assert_not(assertion, message = nil)
    assert !assertion, message
  end

  def assert_not_blank(assertion)
    assert !assertion.blank?
  end
  alias :assert_present :assert_not_blank
end
