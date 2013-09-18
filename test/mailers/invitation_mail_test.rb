require 'test_helper'
require 'model_tests_helper'

class InvitationMailTest < ActionMailer::TestCase

  def setup
    setup_mailer
    Devise.mailer_sender = 'test@example.com'
  end

  def user
    @user ||= User.invite!(:email => "valid@email.com")
  end

  def mail
    @mail ||= begin
      user
      ActionMailer::Base.deliveries.last
    end
  end

  test 'email sent after reseting the user password' do
    assert_not_nil mail
  end

  test 'content type should be set to html' do
    assert_equal 'text/html; charset=UTF-8', mail.content_type
  end

  test 'send invitation to the user email' do
    assert_equal [user.email], mail.to
  end

  test 'setup sender from configuration' do
    assert_equal ['test@example.com'], mail.from
  end

  test 'setup subject from I18n' do
    store_translations :en, :devise => { :mailer => { :invitation_instructions => { :subject => 'Localized Invitation' } } } do
      assert_equal 'Localized Invitation', mail.subject
    end
  end

  test 'subject namespaced by model' do
    store_translations :en, :devise => { :mailer => { :invitation_instructions => { :user_subject => 'User Invitation' } } } do
      assert_equal 'User Invitation', mail.subject
    end
  end

  test 'body should have user info' do
    assert_match /#{user.email}/, mail.body.decoded
  end

  test 'body should have link to confirm the account' do
    host = ActionMailer::Base.default_url_options[:host]
    body = mail.body.decoded
    invitation_url_regexp = %r{<a href=\"http://#{host}/users/invitation/accept\?invitation_token=#{Thread.current[:token]}">}
    assert_match invitation_url_regexp, body
  end

  test 'body should have link to confirm the account on resend' do
    host = ActionMailer::Base.default_url_options[:host]
    user
    @user = User.find(user.id).invite!
    body = mail.body.decoded
    invitation_url_regexp = %r{<a href=\"http://#{host}/users/invitation/accept\?invitation_token=#{Thread.current[:token]}">}
    assert_match invitation_url_regexp, body
  end
end
