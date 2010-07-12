class User < ActiveRecord::Base
  devise :database_authenticatable, :validatable, :confirmable, :invitable

  attr_accessible :email, :password, :password_confirmation
end
