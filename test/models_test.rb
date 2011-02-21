require 'test/test_helper'

class ModelsTest < ActiveSupport::TestCase
  def include_module?(klass, mod)
    klass.devise_modules.include?(mod) &&
    klass.included_modules.include?(Devise::Models::const_get(mod.to_s.classify))
  end

  def assert_include_modules(klass, *modules)
    modules.each do |mod|
      assert include_module?(klass, mod), "#{klass} not include #{mod}"
    end

    (Devise::ALL - modules).each do |mod|
      assert !include_module?(klass, mod), "#{klass} include #{mod}"
    end
  end

  test 'should include Devise modules' do
    assert_include_modules User, :database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :recoverable
  end

  test 'should have a default value for invite_for' do
    assert_equal 0, User.invite_for
  end

  test 'should have a default value for invitation_limit' do
    assert_nil User.invitation_limit
  end

  test 'set a custom value for invite_for' do
    old_invite_for = User.invite_for
    User.invite_for = 5.days
    
    assert_equal 5.days, User.invite_for
    
    User.invite_for = old_invite_for
  end

  test 'set a custom value for invitation_limit' do
    old_invitation_limit = User.invitation_limit
    User.invitation_limit = 2

    assert_equal 2, User.invitation_limit

    User.invitation_limit = old_invitation_limit
  end

  test 'invitable attributes' do
    assert_nil User.new.invitation_token
    assert_nil User.new.invitation_sent_at
  end
end
