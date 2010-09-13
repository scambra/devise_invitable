class User < ActiveRecord::Base
  devise :database_authenticatable, :confirmable, :invitable
  attr_accessible :username, :email, :password, :password_confirmation
end
