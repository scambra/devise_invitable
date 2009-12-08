require 'test/test_helper'

class MapRoutingTest < ActionController::TestCase

  test 'map new user invitation' do
    assert_recognizes({:controller => 'invitations', :action => 'new'}, {:path => 'users/invitation/new', :method => :get})
  end

  test 'map create user invitation' do
    assert_recognizes({:controller => 'invitations', :action => 'create'}, {:path => 'users/invitation', :method => :post})
  end

  test 'map edit user invitation' do
    assert_recognizes({:controller => 'invitations', :action => 'edit'}, 'users/invitation/edit')
  end

  test 'map update user invitation' do
    assert_recognizes({:controller => 'invitations', :action => 'update'}, {:path => 'users/invitation', :method => :put})
  end
end
