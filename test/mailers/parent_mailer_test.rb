require 'test_helper'
require 'open3'

class ParentMailerTest < ActiveSupport::TestCase
  APPLICATION = File.expand_path('../rails_app/config/application', __dir__)

  # Each boot runs in a fresh process: the failure only shows up when nothing has loaded
  # ActionMailer::Base yet, which is never the case inside this test process.
  def boot_with_app_parent_mailer(first_reference)
    script = <<~RUBY
      require #{APPLICATION.inspect}
      Devise.parent_mailer = 'ApplicationMailer'
      RailsApp::Application.initialize!
      #{first_reference}
      print "invitation_instructions=\#{Devise.mailer.method_defined?(:invitation_instructions)}"
    RUBY
    Open3.capture3({ 'RAILS_ENV' => 'test' }, RbConfig.ruby, '-e', script)
  end

  test 'Devise.mailer resolves when the parent mailer is an app mailer' do
    stdout, stderr, status = boot_with_app_parent_mailer('Devise.mailer')
    assert status.success?, stderr
    assert_match(/invitation_instructions=true\z/, stdout)
  end

  test 'the parent mailer can be the first mailer loaded, as with eager loading' do
    stdout, stderr, status = boot_with_app_parent_mailer('ApplicationMailer')
    assert status.success?, stderr
    assert_match(/invitation_instructions=true\z/, stdout)
  end
end
