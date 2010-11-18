require 'test/test_helper'

class ModelsTest < ActiveSupport::TestCase

  test 'should include Devise modules' do
    [:database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :encryptable].each do |mod|
      User.devise_modules.should include mod
      User.included_modules.should include Devise::Models::const_get(mod.to_s.classify)
    end
  end

  test 'should not include other Devise modules' do
    (Devise::ALL - [:database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :encryptable]).each do |mod|
      User.devise_modules.should_not include mod
      User.included_modules.should_not include Devise::Models::const_get(mod.to_s.classify)
    end
  end

  test 'should have a default value for invite_for' do
    assert_equal 0, User.invite_for
  end

  test 'set a custom value for invite_for' do
    old_invite_for = User.invite_for
    User.invite_for = 5.days
    
    assert_equal 5.days, User.invite_for
    
    User.invite_for = old_invite_for
  end

  test 'invitable attributes' do
    assert_nil User.new.invitation_token
    assert_nil User.new.invitation_sent_at
  end
end
