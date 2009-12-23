class ActionController::IntegrationTest

  def warden
    request.env['warden']
  end
  
  def sign_in_as_user
    Warden::Proxy.any_instance.stubs(:user).at_least_once.returns(User.new)
  end

  def create_user(accept_invitation = true)
    user = User.new :email => 'newuser@test.com'
    user.skip_confirmation!
    user.invitation_token = 'token'
    user.invitation_sent_at = Time.now.utc
    user.save(false)
    user.accept_invitation! if accept_invitation
    user
  end

  # Fix assert_redirect_to in integration sessions because they don't take into
  # account Middleware redirects.
  #
  def assert_redirected_to(url)
    assert [301, 302].include?(@integration_session.status),
           "Expected status to be 301 or 302, got #{@integration_session.status}"

    url = prepend_host(url)
    location = prepend_host(@integration_session.headers["Location"])
    assert_equal url, location
  end

  protected

    def prepend_host(url)
      url = "http://#{request.host}#{url}" if url[0] == ?/
      url
    end
end
