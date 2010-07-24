require 'test/test_helper'

class MapRoutingTest < ActionController::TestCase
  
  test 'route new user invitation' do
    assert_routing({ :path => 'users/invitation/new', :method => :get }, { :controller => 'devise/invitations', :action => 'new' })
  end
  
  test 'route create user invitation' do
    assert_routing({ :path => 'users/invitation', :method => :post }, { :controller => 'devise/invitations', :action => 'create' })
  end
  
  test 'route edit user invitation' do
    assert_routing({ :path => 'users/invitation/accept', :method => :get }, { :controller => 'devise/invitations', :action => 'accept' })
  end
  
  test 'route update user invitation' do
    assert_routing({ :path => 'users/invitation', :method => :put }, { :controller => 'devise/invitations', :action => 'update' })
  end
  
end