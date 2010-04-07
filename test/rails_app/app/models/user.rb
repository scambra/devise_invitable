class User < ActiveRecord::Base
  devise :database_authenticatable, :confirmable, :recoverable, :rememberable, :validatable
  attr_accessible :username, :email, :password, :password_confirmation
end
