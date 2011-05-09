class User < PARENT_MODEL_CLASS
  include Mongoid::Document if DEVISE_ORM == :mongoid
  devise :database_authenticatable, :registerable, :validatable, :confirmable, :invitable, :recoverable
  
  attr_accessible :email, :username, :password, :password_confirmation, :skip_invitation
  
  validates :username, :length => { :maximum => 20 }
end
