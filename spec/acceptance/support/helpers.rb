module HelperMethods
  
  def warden
    request.env['warden']
  end
  
  def create_user(options = {})
    @current_user ||= begin
      user = Factory(:user, options[:user] || {})
      user.confirm! unless options[:confirm] == false
      user.lock! if options[:locked] == true
      user
    end
  end
  
  def create_admin(options = {})
    @current_admin ||= begin
      admin = Factory(:admin, options[:admin] || {})
      admin.accept_invitation! unless options[:accept_invitation] == false
      admin.lock! if options[:locked] == true
      admin
    end
  end
  
  def sign_in_as(resource_name, options = {}, &block)
    send(:"sign_in_as_#{resource_name}", { resource_name => options }, &block)
  end
  
  def sign_in_as_user(options = {}, &block)
    user = create_user(options)
    visit "http://www.example.com/users/sign_in"
    fill_in 'Email',    :with => user.email
    fill_in 'Password', :with => '123456'
    check   'Remember me' if options[:remember_me] == true
    yield if block_given?
    click_button 'Sign in'
    user
  end
  
  def sign_in_as_admin(options = {}, &block)
    admin = create_admin(options)
    visit "http://www.example.com/admins/sign_in"
    fill_in 'Email',    :with => admin.email
    fill_in 'Password', :with => '123456'
    check   'Remember me' if options[:remember_me] == true
    yield if block_given?
    click_button 'Sign in'
    admin
  end
  
  def sign_out
    visit "http://www.example.com/users/sign_out"
  end
  
  def invite
    sign_in_as_user
    visit "http://www.example.com/users/invitation/new"
    fill_in 'Email', :with => 'user@test.com'
    yield if block_given?
    click_button 'Send an invitation'
    User.last
  end
  
  def accept_invitation(options = {})
    unless options[:visit] == false
      visit "http://www.example.com/users/invitation/accept?invitation_token=#{options[:invitation_token]}"
    end
    fill_in 'Password', :with => '987654321'
    fill_in 'Password confirmation', :with => '987654321'
    yield if block_given?
    click_button 'Set my password'
  end
  
end

Rspec.configuration.include(HelperMethods)