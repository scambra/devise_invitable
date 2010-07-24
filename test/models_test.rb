require 'test/test_helper'

class Invitable < User
  devise :invitable, :invite_for => 2.weeks, :validate_on_invite => true
end

class ActiveRecordTest < ActiveSupport::TestCase
  def include_module?(klass, mod)
    klass.devise_modules.include?(mod) &&
    klass.included_modules.include?(Devise::Models::const_get(mod.to_s.classify))
  end
  
  def assert_include_modules(klass, *modules)
    modules.each do |mod|
      assert include_module?(klass, mod), "#{klass} doesn't include #{mod}!"
    end
    
    (Devise::ALL - modules).each do |mod|
      assert_not include_module?(klass, mod), "#{klass} includes #{mod}!"
    end
  end
  
  test 'add specified modules only' do
    assert_include_modules Invitable, :database_authenticatable, :validatable, :confirmable, :invitable
  end
  
  test 'set a default value for invite_for' do
    assert_equal 0, User.invite_for
  end
  
  test 'set a default value for validate_on_invite' do
    assert_equal false, User.validate_on_invite
  end
  
  test 'set a custom value for invite_for' do
    assert_equal 2.weeks, Invitable.invite_for
  end
  
  test 'set a custom value for validate_on_invite' do
    assert_equal true, Invitable.validate_on_invite
  end
  
  test 'invitable attributes' do
    assert_nil Invitable.new.invitation_token
    assert_nil Invitable.new.invitation_sent_at
  end
end