require 'active_support/test_case'

class ActiveSupport::TestCase
  def assert_not(assertion, message = nil)
    assert !assertion, message
  end
  
  def assert_blank(assertion)
    assert assertion.blank?
  end
  
  def assert_not_blank(assertion)
    assert assertion.present?
  end
  alias :assert_present :assert_not_blank
  
  def assert_email_sent(emails_count = 1, &block)
    assert_difference('ActionMailer::Base.deliveries.size', emails_count) { yield }
  end
  
  def assert_email_not_sent(&block)
    assert_no_difference('ActionMailer::Base.deliveries.size') { yield }
  end
end
