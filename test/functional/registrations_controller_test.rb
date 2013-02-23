require 'test_helper'
require 'model_tests_helper'

class DeviseInvitable::RegistrationsControllerTest < ActionController::TestCase
  def setup
    @issuer = new_user#users(:issuer)
    @issuer.valid?
    assert @issuer.valid?, 'starting with a valid user record'

    # josevalim: you are required to do that because the routes sets this kind
    # of stuff automatically. But functional tests are not using the routes.
    # see https://github.com/plataformatec/devise/issues/1196
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  test "invited users may still sign up directly by themselves" do
    # invite the invitee
    sign_in @issuer
    invitee_email = "invitee@example.org"

    User.invite!(:email => invitee_email) do |u|
      u.skip_invitation = true
      u.invited_by = @issuer
    end
    sign_out @issuer

    @invitee = User.where(:email => invitee_email).first
    assert_blank @invitee.encrypted_password, "the password should be unset"

    # sign_up the invitee
    assert_difference('ActionMailer::Base.deliveries.size') do
      post :create, :user => {:email => invitee_email, :password => "1password", :bio => '.'}
    end

    @invitee = User.where(:email => invitee_email).first
    assert_present @invitee.encrypted_password
    assert_not_nil @invitee.invitation_accepted_at
    assert_nil @invitee.invitation_token
    assert_present @invitee.invited_by_id
    assert_present @invitee.invited_by_type
    assert !@invitee.confirmed?
    assert_present @invitee.confirmation_token
  end

  test "not invitable resources can register" do
    @request.env["devise.mapping"] = Devise.mappings[:admin]
    invitee_email = "invitee@example.org"

    post :create, :admin => {:email => invitee_email, :password => "1password"}

    @invitee = Admin.where(:email => invitee_email).first
    assert_present @invitee.encrypted_password
  end

  test "missing params on a create should not cause an error" do

    assert_nothing_raised { post :create }
  end
end
