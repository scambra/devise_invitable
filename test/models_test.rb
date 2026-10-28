require 'test_helper'

class Invitable < User
  devise :invitable, invite_for: 5.days, validate_on_invite: true
end

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

  test 'does not create placeholder resources by default' do
    assert_equal false, Devise.create_resource_on_invitation
  end

  test 'should have a default value for invite_key' do
    assert !User.invite_key.nil?
  end

  test 'set a custom value for invite_for' do
    old_invite_for = User.invite_for
    User.invite_for = 5.days

    assert_equal 5.days, User.invite_for

    User.invite_for = old_invite_for
  end

  test 'set a custom value for invite_key' do
    old_invite_key = User.invite_key
    User.invite_key = { username: /\A.+\z/}

    assert_equal({ username: /\A.+\z/ }, User.invite_key)

    User.invite_key = old_invite_key
  end

  test 'set a custom value for invitation_limit' do
    old_invitation_limit = User.invitation_limit
    User.invitation_limit = 2

    assert_equal 2, User.invitation_limit

    User.invitation_limit = old_invitation_limit
  end

  test 'warns when deprecated invited_by settings are configured globally' do
    DeviseInvitable.deprecator.expects(:warn).with(includes('invited_by_class_name')).once
    DeviseInvitable.deprecator.expects(:warn).with(includes('invited_by_foreign_key')).once

    Devise.invited_by_class_name = 'Admin'
    Devise.invited_by_foreign_key = :inviter_id
  ensure
    Devise.class_variable_set(:@@invited_by_class_name, nil)
    Devise.class_variable_set(:@@invited_by_foreign_key, nil)
  end

  test 'warns when deprecated invited_by settings are configured on a model' do
    DeviseInvitable.deprecator.expects(:warn).with(includes('invited_by_class_name')).once
    DeviseInvitable.deprecator.expects(:warn).with(includes('invited_by_foreign_key')).once

    model = Class.new(User) do
      devise :invitable,
        invited_by_class_name: 'Admin',
        invited_by_foreign_key: :inviter_id
    end

    assert_equal 'Admin', model.invited_by_class_name
    assert_equal :inviter_id, model.invited_by_foreign_key
  end

  test 'set a default value for validate_on_invite' do
    assert_equal true, Invitable.validate_on_invite
  end

  test 'invitable attributes' do
    assert_nil User.new.invitation_token
    assert_nil User.new.invitation_sent_at
    #raw token
    assert_nil User.new.raw_invitation_token
    #encrypted token - alias to invitation token
    assert_nil User.new.encrypted_invitation_token
  end
end
